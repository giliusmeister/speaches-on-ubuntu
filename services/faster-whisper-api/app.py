import os
from tempfile import NamedTemporaryFile
from typing import Any

from faster_whisper import WhisperModel
from fastapi import FastAPI, File, Form, UploadFile


app = FastAPI(title="Faster Whisper API")

_model: WhisperModel | None = None


def get_model() -> WhisperModel:
    global _model
    if _model is None:
        _model = WhisperModel(
            os.getenv("WHISPER_MODEL", "small"),
            device=os.getenv("WHISPER_DEVICE", "cpu"),
            compute_type=os.getenv("WHISPER_COMPUTE_TYPE", "int8"),
        )
    return _model


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/stt")
async def transcribe(
    file: UploadFile = File(...),
    language: str | None = Form(default=None),
    prompt: str | None = Form(default=None),
) -> dict[str, Any]:
    suffix = os.path.splitext(file.filename or "audio.wav")[1] or ".wav"
    with NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
        temp_file.write(await file.read())
        temp_path = temp_file.name

    try:
        model = get_model()
        segments, info = model.transcribe(
            temp_path,
            language=language or os.getenv("WHISPER_LANGUAGE") or None,
            initial_prompt=prompt or None,
        )
        segment_list = list(segments)
        text = "".join(segment.text for segment in segment_list).strip()

        return {
            "text": text,
            "provider": "faster-whisper",
            "model": os.getenv("WHISPER_MODEL", "small"),
            "language": info.language,
            "duration": info.duration,
            "segments": [
                {
                    "id": index,
                    "start": segment.start,
                    "end": segment.end,
                    "text": segment.text,
                }
                for index, segment in enumerate(segment_list)
            ],
        }
    finally:
        try:
            os.remove(temp_path)
        except FileNotFoundError:
            pass
