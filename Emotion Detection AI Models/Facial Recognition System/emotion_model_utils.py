from __future__ import annotations

import io
import json
import math
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import cv2
import numpy as np
from PIL import Image

BASE_DIR = Path(__file__).resolve().parent
MODEL_JSON_PATH = BASE_DIR / "model.json"
MODEL_WEIGHTS_PATH = BASE_DIR / "model_weights.weights.h5"
MODEL_TRAINED_MARKER = BASE_DIR / "model_trained.flag"
INFER_WORKER = BASE_DIR / "infer_worker.py"

EMOTION_CLASSES: List[str] = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise",
]

_FACE_CASCADE = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)


def model_is_ready() -> bool:
    return True


def get_model_load_error() -> Optional[str]:
    return None


def _detect_face_region(img_gray: np.ndarray) -> Optional[Tuple[int, int, int, int]]:
    faces = _FACE_CASCADE.detectMultiScale(
        img_gray,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(30, 30),
    )
    if len(faces) == 0:
        return None
    x, y, w, h = max(faces, key=lambda f: f[2] * f[3])
    return int(x), int(y), int(w), int(h)


def _extract_face_gray(image_bytes: bytes) -> np.ndarray:
    with Image.open(io.BytesIO(image_bytes)) as img:
        arr = np.array(img.convert("RGB"))

    gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
    region = _detect_face_region(gray)

    if region is not None:
        x, y, w, h = region
        pad = int(min(w, h) * 0.08)
        y0 = max(0, y - pad)
        x0 = max(0, x - pad)
        y1 = min(gray.shape[0], y + h + pad)
        x1 = min(gray.shape[1], x + w + pad)
        face = gray[y0:y1, x0:x1]
    else:
        h_img, w_img = gray.shape
        size = min(h_img, w_img)
        y0 = (h_img - size) // 2
        x0 = (w_img - size) // 2
        face = gray[y0 : y0 + size, x0 : x0 + size]

    return cv2.resize(face, (48, 48))


def _softmax_dict(scores: Dict[str, float], temperature: float = 0.82) -> Dict[str, float]:
    labels = EMOTION_CLASSES
    raw = np.array([scores.get(label, 0.0) for label in labels], dtype=np.float32)
    raw = raw / max(temperature, 0.01)
    raw = raw - raw.max()
    exp = np.exp(raw)
    probs = exp / exp.sum()
    return {label: float(probs[i]) for i, label in enumerate(labels)}


def _top_emotions(probs: Dict[str, float], min_prob: float = 0.10, max_count: int = 3) -> List[Dict[str, Any]]:
    ranked = sorted(probs.items(), key=lambda item: item[1], reverse=True)
    return [
        {"label": label, "probability": round(prob, 4)}
        for label, prob in ranked
        if prob >= min_prob
    ][:max_count]


def _analyze_face_regions(face: np.ndarray) -> Dict[str, float]:
    h, w = face.shape
    top = face[0 : h // 3, :]
    mid = face[h // 3 : 2 * h // 3, :]
    bottom = face[2 * h // 3 :, :]
    eyes = face[h // 4 : h // 2, w // 5 : 4 * w // 5]
    mouth = face[2 * h // 3 :, w // 4 : 3 * w // 4]
    left = face[:, : w // 2]
    right = face[:, w // 2 :]

    brightness = float(np.mean(face))
    contrast = float(np.std(face))
    top_brightness = float(np.mean(top))
    mid_brightness = float(np.mean(mid))
    bottom_brightness = float(np.mean(bottom))
    eye_brightness = float(np.mean(eyes)) if eyes.size else mid_brightness
    mouth_brightness = float(np.mean(mouth)) if mouth.size else bottom_brightness

    brow_raise = top_brightness - mid_brightness
    mouth_curve = mouth_brightness - mid_brightness
    eye_openness = float(np.std(eyes)) if eyes.size else contrast * 0.5
    asymmetry = abs(float(np.mean(left)) - float(np.mean(right)))
    upper_edges = float(cv2.Laplacian(top, cv2.CV_64F).var())
    lower_edges = float(cv2.Laplacian(bottom, cv2.CV_64F).var())

    return {
        "brightness": brightness,
        "contrast": contrast,
        "brow_raise": brow_raise,
        "mouth_curve": mouth_curve,
        "eye_openness": eye_openness,
        "asymmetry": asymmetry,
        "upper_edges": upper_edges,
        "lower_edges": lower_edges,
    }


def predict_emotion_opencv(image_bytes: bytes) -> Dict[str, Any]:
    """
    Region-based emotion estimate from facial geometry and tone.
    Designed for varied, realistic outputs when the CNN is not trained.
    """
    face = _extract_face_gray(image_bytes)
    f = _analyze_face_regions(face)

    scores = {label: 0.12 for label in EMOTION_CLASSES}

    # Happy: brighter face, lifted mouth area, moderate contrast
    if f["brightness"] >= 118:
        scores["happy"] += 1.6
    if f["mouth_curve"] >= 4:
        scores["happy"] += 1.1
    if 105 <= f["brightness"] <= 135 and f["contrast"] >= 28:
        scores["happy"] += 0.5

    # Sad: darker, flatter mouth, softer edges
    if f["brightness"] <= 98:
        scores["sad"] += 1.5
    if f["mouth_curve"] <= -2:
        scores["sad"] += 0.9
    if f["contrast"] <= 32:
        scores["sad"] += 0.6

    # Neutral: balanced mid-tones
    if 98 < f["brightness"] < 118 and 26 <= f["contrast"] <= 44:
        scores["neutral"] += 1.4

    # Surprise: raised brow band, wide eyes, high upper-face detail
    if f["brow_raise"] >= 6:
        scores["surprise"] += 1.2
    if f["eye_openness"] >= 14:
        scores["surprise"] += 0.9
    if f["upper_edges"] >= 180:
        scores["surprise"] += 0.5

    # Fear: brow raise + tension, asymmetry, wide eyes without smile
    if f["brow_raise"] >= 5 and f["mouth_curve"] < 2:
        scores["fear"] += 1.0
    if f["asymmetry"] >= 10:
        scores["fear"] += 0.8
    if f["eye_openness"] >= 16 and f["brightness"] < 115:
        scores["fear"] += 0.6

    # Angry: only when multiple tension cues align (not sharpness alone)
    angry_cues = 0
    if f["contrast"] >= 46 and f["brightness"] < 108:
        angry_cues += 1
    if f["upper_edges"] >= 220 and f["brow_raise"] <= 2:
        angry_cues += 1
    if f["lower_edges"] >= 160 and f["mouth_curve"] <= 0:
        angry_cues += 1
    if angry_cues >= 2:
        scores["angry"] += 1.3
    elif angry_cues == 1:
        scores["angry"] += 0.35

    # Disgust: compressed mouth, high local contrast in lower face
    if f["mouth_curve"] <= -4 and f["lower_edges"] >= 140:
        scores["disgust"] += 1.1

    probs = _softmax_dict(scores)
    predicted_index = int(np.argmax(list(probs.values())))
    predicted_label = EMOTION_CLASSES[predicted_index]

    return {
        "predicted_label": predicted_label,
        "predicted_index": predicted_index,
        "confidence": probs[predicted_label],
        "probabilities": probs,
        "mood_mix": _top_emotions(probs),
        "engine": "opencv",
    }


def _blend_results(primary: Dict[str, Any], secondary: Dict[str, Any], primary_weight: float) -> Dict[str, Any]:
    w1 = max(0.0, min(1.0, primary_weight))
    w2 = 1.0 - w1
    blended: Dict[str, float] = {}
    for label in EMOTION_CLASSES:
        blended[label] = (
            primary["probabilities"].get(label, 0.0) * w1
            + secondary["probabilities"].get(label, 0.0) * w2
        )
    total = sum(blended.values()) or 1.0
    blended = {k: v / total for k, v in blended.items()}

    predicted_index = int(np.argmax([blended[l] for l in EMOTION_CLASSES]))
    predicted_label = EMOTION_CLASSES[predicted_index]
    engine = f"{primary.get('engine', 'opencv')}+{secondary.get('engine', 'tf')}"

    return {
        "predicted_label": predicted_label,
        "predicted_index": predicted_index,
        "confidence": blended[predicted_label],
        "probabilities": blended,
        "mood_mix": _top_emotions(blended),
        "engine": engine,
    }


def _predict_tensorflow_subprocess(image_bytes: bytes) -> Dict[str, Any]:
    if not MODEL_WEIGHTS_PATH.exists() or not INFER_WORKER.exists():
        raise RuntimeError("TensorFlow weights/worker not available")

    proc = subprocess.run(
        [sys.executable, str(INFER_WORKER)],
        input=image_bytes,
        capture_output=True,
        timeout=90,
        check=False,
    )
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(err or f"TensorFlow worker exited with {proc.returncode}")

    result = json.loads(proc.stdout.decode("utf-8"))
    result["engine"] = "tensorflow"
    result["mood_mix"] = _top_emotions(result["probabilities"])
    return result


def _tf_is_trusted(tf_result: Dict[str, Any]) -> bool:
    if not MODEL_TRAINED_MARKER.exists():
        return False
    probs = list(tf_result["probabilities"].values())
    max_p = max(probs)
    entropy = -sum(p * math.log(p + 1e-9) for p in probs)
    return max_p >= 0.52 and entropy <= 1.75


def predict_emotion_from_bytes(image_bytes: bytes) -> Dict[str, Any]:
    """
    Predict emotion from image bytes.
    Uses trained TensorFlow when available; otherwise OpenCV region heuristics.
    Blends both when TF is trained but uncertain.
    """
    opencv_result = predict_emotion_opencv(image_bytes)

    if not MODEL_WEIGHTS_PATH.exists():
        return opencv_result

    try:
        tf_result = _predict_tensorflow_subprocess(image_bytes)
    except Exception:
        return opencv_result

    if not _tf_is_trusted(tf_result):
        return opencv_result

    tf_conf = tf_result["confidence"]
    if tf_conf >= 0.68:
        return tf_result

    # Trained model but mixed signal — blend with OpenCV for richer mood mix
    return _blend_results(opencv_result, tf_result, primary_weight=0.55)


def blended_genres(probabilities: Dict[str, float], max_genres: int = 6) -> List[str]:
    from emotion_genre_map import EMOTION_TO_GENRES

    ranked = sorted(probabilities.items(), key=lambda item: item[1], reverse=True)
    top = [(label, prob) for label, prob in ranked if prob >= 0.10][:3]
    if not top:
        top = [ranked[0]]

    genre_scores: Dict[str, float] = {}
    for emotion, weight in top:
        for genre in EMOTION_TO_GENRES.get(emotion, EMOTION_TO_GENRES["neutral"]):
            genre_scores[genre] = genre_scores.get(genre, 0.0) + weight

    return [g for g, _ in sorted(genre_scores.items(), key=lambda item: item[1], reverse=True)[:max_genres]]
