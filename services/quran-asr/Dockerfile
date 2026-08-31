FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MODEL_DIR=/models/quran-asr \
    COMPUTE_TYPE=int8 \
    PORT=8080

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

# Quran-tuned weights baked in: KheemP/whisper-base-quran-lora merged into
# tarteel-ai/whisper-base-ar-quran, converted to CTranslate2 (fp16). Beats
# plain tarteel-base head-to-head (~19% fewer errors) and is diacritic-aware,
# same 74M size. Regenerate with services/quran-asr/build_model.md.
COPY model/ /models/quran-asr/

COPY main.py .

CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT}
