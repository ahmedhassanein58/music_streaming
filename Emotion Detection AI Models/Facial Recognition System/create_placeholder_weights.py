#!/usr/bin/env python3
"""Create placeholder model_weights.h5 from model.json so the API can start."""
from pathlib import Path
from tensorflow.keras.models import model_from_json

BASE = Path(__file__).resolve().parent
with (BASE / "model.json").open() as f:
    model = model_from_json(f.read())
model.save_weights(str(BASE / "model_weights.weights.h5"))
print(f"Created {BASE / 'model_weights.weights.h5'}")
print("Run train_model.py for trained weights with real accuracy.")
