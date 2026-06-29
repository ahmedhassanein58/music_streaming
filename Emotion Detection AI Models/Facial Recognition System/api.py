from __future__ import annotations

from typing import Any, Dict

from fastapi import FastAPI, File, HTTPException, UploadFile

from emotion_model_utils import (
    EMOTION_CLASSES,
    blended_genres,
    model_is_ready,
    predict_emotion_from_bytes,
)


app = FastAPI(title="Facial Emotion Recognition API")


@app.get("/health")
def health() -> Dict[str, Any]:
    return {"status": "ok", "model_ready": model_is_ready(), "engine": "opencv-fallback-with-tensorflow-subprocess"}


@app.post("/emotion/predict")
async def predict_emotion(file: UploadFile = File(...)) -> Dict[str, Any]:
    """
    Predict facial emotion from an uploaded image.
    """
    if not model_is_ready():
        raise HTTPException(
            status_code=503,
            detail="Model weights not found. Run: python3 train_model.py",
        )

    try:
        contents = await file.read()
        result = predict_emotion_from_bytes(contents)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        "filename": file.filename,
        "predicted_label": result["predicted_label"],
        "predicted_index": result["predicted_index"],
        "confidence": result["confidence"],
        "probabilities": result["probabilities"],
        "mood_mix": result.get("mood_mix", []),
        "classes": EMOTION_CLASSES,
        "engine": result.get("engine", "opencv"),
    }


@app.post("/emotion/predict-with-genres")
async def predict_emotion_with_genres(file: UploadFile = File(...)) -> Dict[str, Any]:
    """
    Predict facial emotion and return mapped music genres.
    """
    if not model_is_ready():
        raise HTTPException(
            status_code=503,
            detail="Model weights not found. Run: python3 train_model.py",
        )

    try:
        contents = await file.read()
        result = predict_emotion_from_bytes(contents)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    emotion = result["predicted_label"]
    probs = result["probabilities"]
    return {
        "filename": file.filename,
        "predicted_label": emotion,
        "predicted_index": result["predicted_index"],
        "confidence": result["confidence"],
        "probabilities": probs,
        "mood_mix": result.get("mood_mix", []),
        "classes": EMOTION_CLASSES,
        "genres": blended_genres(probs),
        "engine": result.get("engine", "opencv"),
    }
