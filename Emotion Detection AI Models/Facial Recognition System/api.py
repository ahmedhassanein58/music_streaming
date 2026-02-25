from __future__ import annotations

from typing import Any, Dict

from fastapi import FastAPI, File, HTTPException, UploadFile

from emotion_model_utils import EMOTION_CLASSES, predict_emotion_from_bytes


app = FastAPI(title="Facial Emotion Recognition API")


@app.post("/emotion/predict")
async def predict_emotion(file: UploadFile = File(...)) -> Dict[str, Any]:
    """
    Predict facial emotion from an uploaded image.

    The backend can call this endpoint by sending a multipart/form-data
    request with an image file under the "file" field.
    """
    try:
        contents = await file.read()
        result = predict_emotion_from_bytes(contents)
    except FileNotFoundError as exc:
        # model files missing on the server
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return {
        "filename": file.filename,
        "predicted_label": result["predicted_label"],
        "predicted_index": result["predicted_index"],
        "probabilities": result["probabilities"],
        "classes": EMOTION_CLASSES,
    }


# To run locally:
#   uvicorn api:app --reload

