from __future__ import annotations

import io
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np
from PIL import Image
from tensorflow.keras.models import model_from_json


BASE_DIR = Path(__file__).resolve().parent
MODEL_JSON_PATH = BASE_DIR / "model.json"
MODEL_WEIGHTS_PATH = BASE_DIR / "model_weights.h5"

# Order taken from notebook output:
# Generator Class Indices: {'angry': 0, 'disgust': 1, 'fear': 2, 'happy': 3,
#                           'neutral': 4, 'sad': 5, 'surprise': 6}
EMOTION_CLASSES: List[str] = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise",
]

_MODEL = None


def load_emotion_model():
    """
    Load the CNN emotion recognition model from JSON + H5 weights.

    The model is cached globally after the first load.
    """
    global _MODEL
    if _MODEL is not None:
        return _MODEL

    if not MODEL_JSON_PATH.exists():
        raise FileNotFoundError(f"model.json not found at {MODEL_JSON_PATH}")
    if not MODEL_WEIGHTS_PATH.exists():
        raise FileNotFoundError(f"model_weights.h5 not found at {MODEL_WEIGHTS_PATH}")

    with MODEL_JSON_PATH.open("r", encoding="utf-8") as f:
        model_json = f.read()

    model = model_from_json(model_json)
    model.load_weights(str(MODEL_WEIGHTS_PATH))

    # Compilation settings are embedded in the JSON, but for inference-only
    # use it is not strictly necessary to compile. Compile anyway for safety.
    if not hasattr(model, "optimizer") or model.optimizer is None:
        model.compile(
            optimizer="adam",
            loss="categorical_crossentropy",
            metrics=["accuracy"],
        )

    _MODEL = model
    return _MODEL


def preprocess_image_bytes(image_bytes: bytes) -> np.ndarray:
    """
    Convert raw image bytes into a model-ready tensor.

    - Converts to grayscale
    - Resizes to 48x48
    - Normalizes to [0, 1]
    - Adds batch and channel dimensions => (1, 48, 48, 1)
    """
    with Image.open(io.BytesIO(image_bytes)) as img:
        img = img.convert("L")  # grayscale
        img = img.resize((48, 48))

    arr = np.array(img).astype("float32") / 255.0
    arr = np.expand_dims(arr, axis=-1)  # (48, 48, 1)
    arr = np.expand_dims(arr, axis=0)  # (1, 48, 48, 1)
    return arr


def predict_emotion_from_bytes(image_bytes: bytes) -> Dict[str, Any]:
    """
    Run inference on raw image bytes and return:
      - predicted_label
      - predicted_index
      - probabilities (per emotion class)
    """
    model = load_emotion_model()
    input_tensor = preprocess_image_bytes(image_bytes)

    preds = model.predict(input_tensor)
    if preds.ndim != 2 or preds.shape[0] != 1:
        raise ValueError(f"Unexpected prediction shape: {preds.shape}")

    probabilities = preds[0]
    predicted_index = int(np.argmax(probabilities))
    predicted_label = EMOTION_CLASSES[predicted_index]

    return {
        "predicted_label": predicted_label,
        "predicted_index": predicted_index,
        "probabilities": {
            label: float(probabilities[i]) for i, label in enumerate(EMOTION_CLASSES)
        },
    }


# Eagerly load model so first API call is fast
load_emotion_model()

