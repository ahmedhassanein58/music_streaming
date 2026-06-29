#!/usr/bin/env python3
"""
Train the facial emotion CNN and save model_weights.h5.

Downloads the Kaggle face-expression dataset via kagglehub, trains the
architecture defined in model.json, and writes weights next to model.json.

Usage:
    pip install -r requirements.txt kagglehub
    python3 train_model.py [--epochs 70] [--batch-size 64]
"""

from __future__ import annotations

import argparse
from pathlib import Path

import kagglehub
import numpy as np
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from tensorflow.keras.models import model_from_json
from tensorflow.keras.preprocessing.image import ImageDataGenerator


BASE_DIR = Path(__file__).resolve().parent
MODEL_JSON_PATH = BASE_DIR / "model.json"
WEIGHTS_PATH = BASE_DIR / "model_weights.weights.h5"

EMOTION_CLASSES = ["angry", "disgust", "fear", "happy", "neutral", "sad", "surprise"]


def load_model() -> "object":
    with MODEL_JSON_PATH.open("r", encoding="utf-8") as f:
        model = model_from_json(f.read())
    model.compile(
        optimizer="adam",
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def main() -> None:
    parser = argparse.ArgumentParser(description="Train facial emotion model")
    parser.add_argument("--epochs", type=int, default=70)
    parser.add_argument("--batch-size", type=int, default=64)
    args = parser.parse_args()

    print("Downloading dataset via kagglehub...")
    dataset_path = Path(kagglehub.dataset_download("jonathanoheix/face-expression-recognition-dataset"))
    train_dir = dataset_path / "train"
    if not train_dir.exists():
        raise FileNotFoundError(f"Expected train/ under {dataset_path}")

    print(f"Dataset at: {dataset_path}")

    train_datagen = ImageDataGenerator(
        rescale=1.0 / 255,
        rotation_range=15,
        width_shift_range=0.1,
        height_shift_range=0.1,
        shear_range=0.1,
        zoom_range=0.1,
        horizontal_flip=True,
        fill_mode="nearest",
        validation_split=0.2,
    )

    train_gen = train_datagen.flow_from_directory(
        str(train_dir),
        target_size=(48, 48),
        color_mode="grayscale",
        batch_size=args.batch_size,
        class_mode="categorical",
        subset="training",
    )
    val_gen = train_datagen.flow_from_directory(
        str(train_dir),
        target_size=(48, 48),
        color_mode="grayscale",
        batch_size=args.batch_size,
        class_mode="categorical",
        subset="validation",
    )

    print("Class indices:", train_gen.class_indices)

    model = load_model()
    callbacks = [
        ModelCheckpoint(str(WEIGHTS_PATH), monitor="val_accuracy", save_best_only=True, verbose=1),
        EarlyStopping(monitor="val_accuracy", patience=10, restore_best_weights=True, verbose=1),
        ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=5, min_lr=1e-6, verbose=1),
    ]

    print(f"Training for up to {args.epochs} epochs...")
    model.fit(
        train_gen,
        validation_data=val_gen,
        epochs=args.epochs,
        callbacks=callbacks,
    )

    model.save_weights(str(WEIGHTS_PATH))
    (BASE_DIR / "model_trained.flag").write_text("trained\n", encoding="utf-8")
    print(f"Saved weights to {WEIGHTS_PATH}")


if __name__ == "__main__":
    main()
