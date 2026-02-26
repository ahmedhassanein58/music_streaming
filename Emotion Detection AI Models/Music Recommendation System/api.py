from __future__ import annotations

from typing import Any, Iterable, List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from recommendation import (
    recommend_by_track_id,
    recommend_from_multiple_songs,
    recommend_songs,
    to_response_list,
)


app = FastAPI(title="Music Recommendation API")


class RecommendByTitleRequest(BaseModel):
    title: str = Field(..., description="Song title to base recommendations on")
    n: int = Field(5, ge=1, le=100, description="Number of recommendations to return")


class RecommendByTrackIdRequest(BaseModel):
    track_id: str = Field(..., description="Track ID to base recommendations on")
    n: int = Field(5, ge=1, le=100, description="Number of recommendations to return")


class RecommendFromMultipleRequest(BaseModel):
    titles: List[str] = Field(
        ..., description="List of song titles to base recommendations on"
    )
    n: int = Field(5, ge=1, le=100, description="Number of recommendations to return")


@app.post("/recommend/by-title")
def api_recommend_by_title(payload: RecommendByTitleRequest) -> dict[str, Any]:
    """
    Recommend songs based on a single song title.

    This wraps the underlying ``recommend_songs`` function from the
    recommendation module and returns a JSON-serializable structure.
    """
    try:
        df = recommend_songs(payload.title, n=payload.n)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return {"items": to_response_list(df)}


@app.post("/recommend/by-track-id")
def api_recommend_by_track_id(payload: RecommendByTrackIdRequest) -> dict[str, Any]:
    """
    Recommend songs based on a track ID.
    """
    try:
        df = recommend_by_track_id(payload.track_id, n=payload.n)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return {"items": to_response_list(df)}


@app.post("/recommend/from-multiple")
def api_recommend_from_multiple(
    payload: RecommendFromMultipleRequest,
) -> dict[str, Any]:
    """
    Recommend songs based on multiple input titles by averaging their feature vectors.
    """
    try:
        df = recommend_from_multiple_songs(payload.titles, n=payload.n)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return {"items": to_response_list(df)}