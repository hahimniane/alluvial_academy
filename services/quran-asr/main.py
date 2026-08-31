"""Quran recitation transcription service (Cloud Run, CPU).

Wraps a Quran-tuned faster-whisper (CTranslate2) model behind a tiny HTTP API.
The browser records a short recitation clip and POSTs it here; we return the
Arabic transcript (plus word timings) which the app aligns against the expected
ayah. Model weights are baked into the image (see Dockerfile), so no runtime
download. Transcription-source only — the matching/grading lives in the app.
"""

import os
import tempfile

from faster_whisper import WhisperModel
from fastapi import FastAPI, File, HTTPException, UploadFile

MODEL_DIR = os.environ.get("MODEL_DIR", "/models/quran-asr")
COMPUTE_TYPE = os.environ.get("COMPUTE_TYPE", "int8")

app = FastAPI(title="Quran ASR")
_model: WhisperModel | None = None


def get_model() -> WhisperModel:
    global _model
    if _model is None:
        _model = WhisperModel(MODEL_DIR, device="cpu", compute_type=COMPUTE_TYPE)
    return _model


@app.get("/")
def health() -> dict:
    return {"status": "ok", "compute_type": COMPUTE_TYPE}


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)) -> dict:
    audio = await file.read()
    if not audio:
        raise HTTPException(status_code=400, detail="empty audio")

    suffix = os.path.splitext(file.filename or "")[1] or ".webm"
    with tempfile.NamedTemporaryFile(suffix=suffix) as tmp:
        tmp.write(audio)
        tmp.flush()
        model = get_model()
        segments, info = model.transcribe(
            tmp.name,
            language="ar",
            beam_size=5,
            word_timestamps=True,
        )
        parts: list[str] = []
        words: list[dict] = []
        for seg in segments:
            text = seg.text.strip()
            if text:
                parts.append(text)
            for w in seg.words or []:
                words.append({"word": w.word.strip(), "start": w.start, "end": w.end})

    return {"text": " ".join(parts).strip(), "words": words, "duration": info.duration}
