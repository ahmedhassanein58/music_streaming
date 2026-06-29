"""Map detected facial emotions to music genres in the Echonova catalog."""

from __future__ import annotations

from typing import Dict, List

EMOTION_TO_GENRES: Dict[str, List[str]] = {
    "happy": ["Pop", "Dance", "Electronic", "Hip-Hop"],
    "sad": ["Blues", "Acoustic", "Indie-Rock", "Folk"],
    "angry": ["Rock", "Loud-Rock", "Metal", "Punk"],
    "fear": ["Ambient", "Electronic", "Psych-Rock"],
    "surprise": ["Pop", "Electronic", "Indie-Rock"],
    "neutral": ["Pop", "Rock", "Hip-Hop"],
    "disgust": ["Experimental", "Loud-Rock", "Metal"],
}


def genres_for_emotion(emotion: str) -> List[str]:
    return EMOTION_TO_GENRES.get(emotion.lower(), EMOTION_TO_GENRES["neutral"])
