import os
from typing import Any

import httpx
from fastapi import FastAPI, File, Form, HTTPException, UploadFile


app = FastAPI(title="OpenLingo STT Adapter")


def _speaches_url() -> str:
    base_url = os.getenv("SPEACHES_BASE_URL", "http://speaches:8000/v1").rstrip("/")
    return f"{base_url}/audio/transcriptions"


def _pick_text(payload: Any) -> str:
    if isinstance(payload, dict):
        text = payload.get("text")
        if isinstance(text, str):
            return text
    raise HTTPException(status_code=502, detail="Speaches response did not include text")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/stt")
async def openlingo_stt(
    file: UploadFile = File(...),
    language: str | None = Form(default=None),
    prompt: str | None = Form(default=None),
    temperature: str | None = Form(default=None),
) -> dict[str, Any]:
    model = os.getenv("SPEACHES_MODEL", "Systran/faster-distil-whisper-small.en")
    response_format = os.getenv("OPENLINGO_RESPONSE_FORMAT", "verbose_json")

    audio_bytes = await file.read()
    multipart_files = {
        "file": (file.filename or "audio.wav", audio_bytes, file.content_type or "application/octet-stream"),
    }
    data = {
        "model": model,
        "response_format": response_format,
    }
    if language:
        data["language"] = language
    if prompt:
        data["prompt"] = prompt
    if temperature:
        data["temperature"] = temperature

    try:
        async with httpx.AsyncClient(timeout=300) as client:
            response = await client.post(_speaches_url(), data=data, files=multipart_files)
            response.raise_for_status()
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text if exc.response is not None else str(exc)
        raise HTTPException(status_code=502, detail=detail) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Speaches request failed: {exc}") from exc

    payload = response.json()
    return {
        "text": _pick_text(payload),
        "provider": "speaches",
        "model": model,
        "raw": payload,
    }
