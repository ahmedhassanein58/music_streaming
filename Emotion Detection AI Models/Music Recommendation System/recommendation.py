from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable, List

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.impute import SimpleImputer
from sklearn.neighbors import NearestNeighbors
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from data_utils import (
    BASE_DIR,
    load_songs,
    one_hot_encode_genres,
    set_track_index,
    validate_and_clean_data,
    songs_to_dataframe,
)


# ── Model preparation on import ────────────────────────────────────────────────

_DATA: pd.DataFrame | None = None
_X_SCALED: np.ndarray | None = None
_KNN_MODEL: NearestNeighbors | None = None


def _prepare_models() -> None:
    """
    Build the full recommendation pipeline:
    - Load songs
    - Build DataFrame
    - One-hot encode genres
    - Validate / clean
    - Select numerical audio features
    - Cluster with KMeans
    - Scale features
    - Train KNN model

    This closely mirrors the logic in the original notebook but is organized
    for reuse from backend / API code.
    """
    global _DATA, _X_SCALED, _KNN_MODEL

    if _DATA is not None and _X_SCALED is not None and _KNN_MODEL is not None:
        return

    # Load and normalize raw songs data
    songs = load_songs()  # defaults to songs.json next to this file
    data = songs_to_dataframe(songs)

    # One-hot encode genres and set index
    data = one_hot_encode_genres(data)
    data = set_track_index(data)

    # Validation / cleaning (drop irrelevant cols, numeric enforcement, dedup)
    data = validate_and_clean_data(data)

    # Feature selection (numerical audio_feature.* columns only)
    exclude_cols = ["artist", "title", "genre", "cluster", "_id", "s3_url"]
    genre_cols = [col for col in data.columns if col.startswith("genre_")]
    exclude_cols.extend(genre_cols)

    all_numeric = data.select_dtypes(include=[np.number])
    feature_cols = [col for col in all_numeric.columns if col not in exclude_cols]
    X = all_numeric[feature_cols]

    # KMeans clustering
    cluster_pipeline: Pipeline = Pipeline(
        [
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
            ("kmeans", KMeans(n_clusters=40, random_state=42)),
        ]
    )
    cluster_pipeline.fit(X)
    data["cluster"] = cluster_pipeline.predict(X)

    # Feature scaling for KNN
    imputer = SimpleImputer(strategy="median")
    X_imputed = imputer.fit_transform(X)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X_imputed)

    # Train KNN model
    knn_model = NearestNeighbors(
        metric="cosine",
        algorithm="auto",
        n_neighbors=50,
    )
    knn_model.fit(X_scaled)

    _DATA = data
    _X_SCALED = X_scaled
    _KNN_MODEL = knn_model


def _ensure_ready() -> tuple[pd.DataFrame, np.ndarray, NearestNeighbors]:
    """
    Ensure that the global models / data are prepared and return them.
    """
    if _DATA is None or _X_SCALED is None or _KNN_MODEL is None:
        _prepare_models()
    assert _DATA is not None and _X_SCALED is not None and _KNN_MODEL is not None
    return _DATA, _X_SCALED, _KNN_MODEL


# ── Public recommendation functions ───────────────────────────────────────────

def recommend_songs(song_title: str, n: int = 5) -> pd.DataFrame:
    """
    Recommend songs based on a given song title using KNN within the same cluster.

    Returns a DataFrame containing:
    - $oid: MongoDB ObjectId (if present)
    - title
    - artist
    - genre
    - similarity_score
    """
    data, X_scaled, knn_model = _ensure_ready()

    song_mask = data["title"].str.lower() == song_title.lower()
    song_indices = data[song_mask].index.tolist()

    if len(song_indices) == 0:
        raise ValueError(f"Song '{song_title}' not found in the dataset")

    song_idx = song_indices[0]
    song_cluster = data.loc[song_idx, "cluster"]
    song_position = data.index.get_loc(song_idx)

    distances, indices = knn_model.kneighbors(
        X_scaled[song_position : song_position + 1],
        n_neighbors=min(100, len(X_scaled)),
    )

    neighbor_indices = indices[0]
    neighbor_distances = distances[0]

    filtered_recommendations: list[dict[str, Any]] = []
    for idx, dist in zip(neighbor_indices, neighbor_distances):
        neighbor_track_id = data.index[idx]

        if neighbor_track_id == song_idx:
            continue

        if data.loc[neighbor_track_id, "cluster"] == song_cluster:
            similarity_score = 1 - float(dist)
            filtered_recommendations.append(
                {"track_id": neighbor_track_id, "similarity_score": similarity_score}
            )

        if len(filtered_recommendations) >= n:
            break

    if not filtered_recommendations:
        raise ValueError(f"No songs found in the same cluster as '{song_title}'")

    result_data: list[dict[str, Any]] = []
    for rec in filtered_recommendations:
        track_id = rec["track_id"]
        oid_value = data.loc[track_id, "_id.$oid"] if "_id.$oid" in data.columns else None
        result_data.append(
            {
                "$oid": oid_value,
                "title": data.loc[track_id, "title"],
                "artist": data.loc[track_id, "artist"],
                "genre": data.loc[track_id, "genre"],
                "similarity_score": rec["similarity_score"],
            }
        )

    return pd.DataFrame(result_data)


def recommend_by_track_id(track_id: str, n: int = 5) -> pd.DataFrame:
    """
    Recommend songs based on track_id, mirroring the notebook's logic.
    """
    data, X_scaled, knn_model = _ensure_ready()

    if track_id not in data.index:
        raise ValueError(f"Track ID '{track_id}' not found in the dataset")

    song_cluster = data.loc[track_id, "cluster"]
    song_position = data.index.get_loc(track_id)

    distances, indices = knn_model.kneighbors(
        X_scaled[song_position : song_position + 1],
        n_neighbors=min(100, len(X_scaled)),
    )

    neighbor_indices = indices[0]
    neighbor_distances = distances[0]

    filtered_recommendations: list[dict[str, Any]] = []
    for idx, dist in zip(neighbor_indices, neighbor_distances):
        neighbor_track_id = data.index[idx]

        if neighbor_track_id == track_id:
            continue

        if data.loc[neighbor_track_id, "cluster"] == song_cluster:
            similarity_score = 1 - float(dist)
            filtered_recommendations.append(
                {"track_id": neighbor_track_id, "similarity_score": similarity_score}
            )

        if len(filtered_recommendations) >= n:
            break

    if not filtered_recommendations:
        raise ValueError(
            f"No songs found in the same cluster as track ID '{track_id}'"
        )

    result_data: list[dict[str, Any]] = []
    for rec in filtered_recommendations:
        rec_track_id = rec["track_id"]
        oid_value = (
            data.loc[rec_track_id, "_id.$oid"] if "_id.$oid" in data.columns else None
        )
        result_data.append(
            {
                "$oid": oid_value,
                "title": data.loc[rec_track_id, "title"],
                "artist": data.loc[rec_track_id, "artist"],
                "genre": data.loc[rec_track_id, "genre"],
                "similarity_score": rec["similarity_score"],
            }
        )

    return pd.DataFrame(result_data)


def recommend_from_multiple_songs(
    song_titles: Iterable[str], n: int = 5
) -> pd.DataFrame:
    """
    Recommend songs based on multiple input songs by averaging their feature vectors.
    """
    titles = list(song_titles)
    if not titles:
        raise ValueError("song_titles list cannot be empty")

    data, X_scaled, knn_model = _ensure_ready()

    song_positions: list[int] = []
    song_clusters: list[int] = []

    for song_title in titles:
        song_mask = data["title"].str.lower() == song_title.lower()
        song_indices = data[song_mask].index.tolist()

        if len(song_indices) == 0:
            raise ValueError(f"Song '{song_title}' not found in the dataset")

        song_idx = song_indices[0]
        song_position = data.index.get_loc(song_idx)
        song_positions.append(song_position)
        song_clusters.append(int(data.loc[song_idx, "cluster"]))

    from collections import Counter

    cluster_counts = Counter(song_clusters)
    target_cluster = cluster_counts.most_common(1)[0][0]

    feature_vectors = X_scaled[song_positions]
    averaged_vector = feature_vectors.mean(axis=0).reshape(1, -1)

    distances, indices = knn_model.kneighbors(
        averaged_vector,
        n_neighbors=min(100, len(X_scaled)),
    )

    input_track_ids = {data.index[pos] for pos in song_positions}

    filtered_recommendations: list[dict[str, Any]] = []
    for idx, dist in zip(indices[0], distances[0]):
        neighbor_track_id = data.index[idx]

        if neighbor_track_id in input_track_ids:
            continue

        if data.loc[neighbor_track_id, "cluster"] == target_cluster:
            similarity_score = 1 - float(dist)
            filtered_recommendations.append(
                {"track_id": neighbor_track_id, "similarity_score": similarity_score}
            )

        if len(filtered_recommendations) >= n:
            break

    if not filtered_recommendations:
        raise ValueError(
            f"No songs found in cluster {target_cluster} matching the input songs"
        )

    result_data: list[dict[str, Any]] = []
    for rec in filtered_recommendations:
        track_id = rec["track_id"]
        oid_value = data.loc[track_id, "_id.$oid"] if "_id.$oid" in data.columns else None
        result_data.append(
            {
                "$oid": oid_value,
                "title": data.loc[track_id, "title"],
                "artist": data.loc[track_id, "artist"],
                "genre": data.loc[track_id, "genre"],
                "similarity_score": rec["similarity_score"],
            }
        )

    return pd.DataFrame(result_data)


def to_response_list(df: pd.DataFrame) -> List[dict[str, Any]]:
    """
    Convert a recommendation DataFrame into a list of dictionaries,
    ready to be serialized as JSON in an API response.
    """
    return df.to_dict(orient="records")


# Prepare models at import so the first API call is fast.
_prepare_models()

