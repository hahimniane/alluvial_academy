FROM python:3.11-slim

# PYTHONHASHSEED pinned: the phonetiser's pronunciation-variant selection is
# hash-order dependent — unpinned, different instances parse the SAME word into
# different token formats (observed in production).
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONHASHSEED=0 \
    CKPT=/models/iqra/model.ckpt \
    DICT=/models/iqra/dict.txt \
    PORT=8080

RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg curl libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install order matters: torch CPU wheels first, then s3prl (pulls its own deps),
# then force the pins s3prl 0.4.18 actually works with (matches the validated
# local prototype environment).
RUN pip install torch==2.1.2+cpu torchaudio==2.1.2+cpu --index-url https://download.pytorch.org/whl/cpu
RUN pip install s3prl==0.4.18 tensorboardX==2.6.2.2 editdistance==0.8.1 soundfile==0.12.1 \
    fastapi==0.111.0 "uvicorn[standard]==0.30.1"
RUN pip install "huggingface_hub==0.16.4" "transformers==4.34.0" "numpy<2"

# IqraEval phoneme model: s3prl CTC checkpoint + its 68-phoneme dict.
RUN mkdir -p /models/iqra \
    && curl -fsSL -o /models/iqra/model.ckpt \
       "https://huggingface.co/IqraEval/Iqra_wav2vec2_base/resolve/main/wave2vec2_base.ckpt" \
    && curl -fsSL -o /models/iqra/dict.txt \
       "https://raw.githubusercontent.com/Iqra-Eval/interspeech_IqraEval/main/vocab/sws_arabic.txt"

COPY phonetiser/ /app/phonetiser/
COPY phoneme_check.py main.py /app/

# Warmup: constructs the model once so s3prl downloads the wav2vec2 upstream
# weights into the image (no runtime download), and validates every import.
RUN python -c "from main import get_model; get_model(); print('warmup ok')"

CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT}
