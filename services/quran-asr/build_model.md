# Regenerating the Quran ASR model (`model/`)

The `model/` dir is the CTranslate2 build baked into the image. It is
**KheemP/whisper-base-quran-lora** (a PEFT LoRA, base `tarteel-ai/whisper-base-ar-quran`)
merged into its base and converted to CTranslate2. This beats plain tarteel-base
head-to-head (~19% fewer errors) at the same 74M size, and is diacritic-aware.

To regenerate:

```bash
python -m venv venv && source venv/bin/activate
pip install torch transformers peft accelerate faster-whisper

python - <<'PY'
import os
from transformers import WhisperForConditionalGeneration, WhisperTokenizerFast, WhisperFeatureExtractor
from peft import PeftModel
BASE="tarteel-ai/whisper-base-ar-quran"; ADAPTER="KheemP/whisper-base-quran-lora"; MERGED="merged"
m = WhisperForConditionalGeneration.from_pretrained(BASE)
m = PeftModel.from_pretrained(m, ADAPTER).merge_and_unload()
m.save_pretrained(MERGED, safe_serialization=True)
WhisperTokenizerFast.from_pretrained(BASE).save_pretrained(MERGED)
WhisperFeatureExtractor.from_pretrained(BASE).save_pretrained(MERGED)
PY

ct2-transformers-converter --model merged --output_dir model \
  --quantization float16 --copy_files tokenizer.json preprocessor_config.json
```

The service loads `model/` with `compute_type=int8` (see `main.py` / `Dockerfile`).
To fall back to the turnkey Tarteel-base build instead, point the Dockerfile at
`OdyAsh/faster-whisper-base-ar-quran` via `snapshot_download`.
