# Backend — FastAPI on Python 3.12.
# Deterministic build: explicit WORKDIR + COPY, no reliance on the builder's
# working-directory detection. Railway builds this Dockerfile directly.
FROM python:3.12-slim

# Don't buffer stdout/stderr (so logs stream) and don't write .pyc files.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Install deps first so this layer is cached until requirements change.
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the application code.
COPY app ./app

# Railway injects $PORT at runtime; default to 8000 for local `docker run`.
ENV PORT=8000
EXPOSE 8000

# Shell form so $PORT expands. Binds all interfaces for the platform proxy.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}
