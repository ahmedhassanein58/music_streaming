"""TensorFlow inference worker — isolated subprocess."""
from __future__ import annotations

import io
import json
import os
import sys

os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
os.environ.setdefault("TF_ENABLE_ONEDNN_OPTS", "0")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import cv2
import numpy as np
from PIL import Image
from tensorflow.keras.models import model_from_json

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_JSON = os.path.join(BASE_DIR, "model.json")
MODEL_WEIGHTS = os.path.join(BASE_DIR, "model_weights.weights.h5")

EMOTION_CLASSES = [
    "angry", "disgust", "fear", "happy", "neutral", "sad", "surprise",
]

_MODEL = None
_CASCADE = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)


def _load_model():
    global _MODEL
    if _MODEL is not None:
        return _MODEL
    with open(MODEL_JSON, encoding="utf-8") as f:
        model = model_from_json(f.read())
    model.load_weights(MODEL_WEIGHTS)
    _MODEL = model
    return _MODEL


def _preprocess(image_bytes: bytes) -> np.ndarray:
    with Image.open(io.BytesIO(image_bytes)) as img:
        arr = np.array(img.convert("RGB"))
    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    faces = _CASCADE.detectMultiScale(gray, 1.1, 5, minSize=(30, 30))
    if len(faces):
        x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
        face = gray[y : y + h, x : x + w]
    else:
        h_img, w_img = gray.shape
        size = min(h_img, w_img)
        face = gray[(h_img - size) // 2 : (h_img + size) // 2, (w_img - size) // 2 : (w_img + size) // 2]
    face = cv2.resize(face, (48, 48))
    arr = face.astype("float32") / 255.0
    return np.expand_dims(np.expand_dims(arr, -1), 0)


def predict_emotion_from_bytes_tf(image_bytes: bytes) -> dict:
    model = _load_model()
    preds = model(_preprocess(image_bytes), training=False).numpy()[0]
    idx = int(np.argmax(preds))
    return {
        "predicted_label": EMOTION_CLASSES[idx],
        "predicted_index": idx,
        "confidence": float(preds[idx]),
        "probabilities": {EMOTION_CLASSES[i]: float(preds[i]) for i in range(len(EMOTION_CLASSES))},
    }


if __name__ == "__main__":
    data = sys.stdin.buffer.read()
    sys.stdout.write(json.dumps(predict_emotion_from_bytes_tf(data)))
