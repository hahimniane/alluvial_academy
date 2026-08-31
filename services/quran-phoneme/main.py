"""Quran pronunciation-check service (Cloud Run, CPU).

POST /check {audio_base64, filename, words: [diacritized imlaei words]} →
per-word verdicts (ok | ending | sound | missed) with harakah-level detail.

The heard side comes from the IqraEval CTC phoneme recognizer (s3prl checkpoint,
greedy decode — no language model, so it transcribes the sounds actually made
and cannot auto-correct to the canonical text). The expected side comes from the
vendored MSA phonetiser. Comparison lives in phoneme_check.py.
"""

import argparse
import base64
import os
import subprocess
import tempfile
from pathlib import Path

import torch
import torchaudio
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from phoneme_check import align_and_classify

CKPT = os.environ.get("CKPT", "/models/iqra/model.ckpt")
DICT = os.environ.get("DICT", "/models/iqra/dict.txt")

torch.set_num_threads(max(1, (os.cpu_count() or 2) - 0))

app = FastAPI(title="Quran Phoneme Check")
_model = None


class S3PRLModel:
    def __init__(self, ckpt: str, dict_path: str):
        from s3prl.downstream.runner import Runner

        if hasattr(torch.serialization, "add_safe_globals"):
            torch.serialization.add_safe_globals([argparse.Namespace])
        md = torch.load(ckpt, map_location="cpu", weights_only=False)
        self.args = md["Args"]
        self.config = md["Config"]
        self.args.init_ckpt = ckpt
        self.args.device = "cpu"
        self.config["downstream_expert"]["text"]["vocab_file"] = dict_path
        self.config["runner"]["upstream_finetune"] = False
        self.config["runner"]["layer_drop"] = False
        self.config["runner"]["downstream_pretrained"] = None
        runner = Runner(self.args, self.config)
        self.upstream = runner._get_upstream()
        self.featurizer = runner._get_featurizer()
        self.downstream = runner._get_downstream()

    def transcribe(self, wav_path: str) -> list[str]:
        wav, _sr = torchaudio.load(wav_path)
        wav = wav.mean(0).unsqueeze(0)
        records = {"loss": [], "hypothesis": [], "groundtruth": [], "filename": []}
        with torch.no_grad():
            feats = self.upstream.model(wav)
            feats = self.featurizer.model(wav, feats)
            self.downstream.model("inference", feats, [[] for _ in feats], [Path(wav_path).stem], records)
        hyp = records["hypothesis"]
        return hyp[0].split() if hyp and isinstance(hyp[0], str) else (hyp[0] if hyp else [])


def get_model() -> S3PRLModel:
    global _model
    if _model is None:
        _model = S3PRLModel(CKPT, DICT)
    return _model


class CheckRequest(BaseModel):
    audio_base64: str
    filename: str = "recitation.webm"
    words: list[str]


@app.get("/")
def health() -> dict:
    return {"status": "ok"}


@app.post("/check")
def check(req: CheckRequest) -> dict:
    if not req.words:
        raise HTTPException(status_code=400, detail="words is required")
    try:
        audio = base64.b64decode(req.audio_base64)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="bad audio_base64") from exc
    if not audio:
        raise HTTPException(status_code=400, detail="empty audio")

    suffix = os.path.splitext(req.filename)[1] or ".webm"
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, f"in{suffix}")
        wav = os.path.join(tmp, "in.wav")
        with open(src, "wb") as f:
            f.write(audio)
        # Browser blobs are webm/opus or mp4 — ffmpeg to 16k mono wav.
        proc = subprocess.run(
            ["ffmpeg", "-y", "-i", src, "-ac", "1", "-ar", "16000", "-f", "wav", wav],
            capture_output=True,
            timeout=60,
        )
        if proc.returncode != 0:
            raise HTTPException(status_code=400, detail="could not decode audio")
        heard = get_model().transcribe(wav)

    results = align_and_classify(req.words, heard)
    return {
        "heard_phonemes": " ".join(heard),
        "words": [
            {
                "word": r.word,
                "status": r.status,
                "expected_ending": r.expected_ending,
                "heard_ending": r.heard_ending,
                "expected_phonemes": " ".join(r.expected_phonemes),
                "heard_word_phonemes": " ".join(r.heard_phonemes),
            }
            for r in results
        ],
    }
