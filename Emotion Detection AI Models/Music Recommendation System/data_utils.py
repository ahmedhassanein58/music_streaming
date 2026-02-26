from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable, List

import numpy as np
import pandas as pd


BASE_DIR = Path(__file__).resolve().parent


def load_songs(json_path: str | Path | None = None) -> List[dict[str, Any]]:
    """
    Load songs from a JSON file.

    Parameters
    ----------
    json_path:
        Path to the JSON file. If None, defaults to ``songs.json`` next to this file.
    """
    path = Path(json_path) if json_path is not None else BASE_DIR / "songs.json"

    with path.open("r", encoding="utf-8") as f:
        songs = json.load(f)

    if not isinstance(songs, list):
        raise ValueError("Expected songs.json to contain a list of song objects.")

    return songs


def songs_to_dataframe(songs: Iterable[dict[str, Any]]) -> pd.DataFrame:
    """
    Convert a list of song dictionaries to a pandas DataFrame.
    """
    data = pd.json_normalize(list(songs))
    return data


def one_hot_encode_genres(data: pd.DataFrame) -> pd.DataFrame:
    """
    One-hot encode the ``genre`` list column into separate ``genre_*`` columns.

    The original ``genre`` column is preserved.
    """
    df = data.copy()

    if "genre" not in df.columns:
        return df

    df["genre"] = df["genre"].apply(lambda x: x if isinstance(x, list) else [])

    all_genres = sorted({g for genre_list in df["genre"] for g in genre_list})

    for g in all_genres:
        col_name = f"genre_{g}"
        df[col_name] = df["genre"].apply(lambda genre_list: int(g in genre_list))

    return df


def set_track_index(data: pd.DataFrame) -> pd.DataFrame:
    """
    Set ``track_id`` as the DataFrame index.
    """
    if "track_id" not in data.columns:
        raise KeyError("Expected 'track_id' column in data.")
    return data.set_index("track_id")


def validate_and_clean_data(data: pd.DataFrame) -> pd.DataFrame:
    """
    Apply basic validation and cleaning steps similar to the notebook:

    - Drop clearly irrelevant columns for recommendations (e.g. ``s3_url``)
    - Ensure numeric dtypes for audio feature columns
    - Remove duplicate rows (excluding list-type columns such as ``genre``)
    """
    df = data.copy()

    # Drop irrelevant columns
    columns_to_drop: list[str] = []
    if "_id" in df.columns and "_id.$oid" not in df.columns:
        columns_to_drop.append("_id")
    if "s3_url" in df.columns:
        columns_to_drop.append("s3_url")

    if columns_to_drop:
        df = df.drop(columns=columns_to_drop)

    # Ensure numerical feature columns are numeric dtype
    audio_feature_cols = [col for col in df.columns if col.startswith("audio_feature.")]
    for col in audio_feature_cols:
        if not np.issubdtype(df[col].dtype, np.number):
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Remove duplicate rows (excluding list columns)
    list_columns: list[str] = []
    for col in df.columns:
        sample_values = df[col].dropna().head(100)
        if len(sample_values) > 0 and any(isinstance(val, list) for val in sample_values):
            list_columns.append(col)

    columns_to_check = [col for col in df.columns if col not in list_columns]
    if columns_to_check:
        df = df.drop_duplicates(subset=columns_to_check)

    return df

