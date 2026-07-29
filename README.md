# Echonova

> **An intelligent music discovery platform that understands both your listening habits and your mood.**

Echonova is a personalized music platform built to make music discovery more intelligent and contextual.

Instead of relying only on listening history, Echonova combines **user behavior, music recommendations, and facial emotion recognition** to recommend music that fits both the user's preferences and their current emotional state.

---

## Features

* **Personalized Recommendations** — recommendations based on listening history and music preferences.
* **AI Mood Detection** — facial emotion recognition using a machine-learning model.
* **Mood-Based Recommendations** — detected emotions are mapped to suitable music genres.
* **Mood Scan** — scan your current facial expression and receive music recommendations.
* **Song Identification** — microphone-based song identification interface.
* **Playlists** — create and manage playlists and use listening activity for recommendations.
* **Recommendation Emails** — personalized music digests delivered daily, weekly, or monthly.
* **User Accounts** — authentication, profiles, preferences, and personalized experiences.

---

## How It Works

Echonova combines two major recommendation signals:

```text
Listening History ──────┐
                        ├──> Recommendation Engine ──> Music
Current Mood ───────────┘
```

For mood-based recommendations:

```text
Face
 ↓
Emotion Recognition
 ↓
Detected Emotion
 ↓
Emotion → Genre Mapping
 ↓
Music Recommendation
 ↓
Personalized Results
```

The facial recognition and recommendation systems run as independent Python services, while the .NET backend orchestrates communication between the application and AI services.

---

## Architecture

```text
┌─────────────────────┐
│    Flutter Client   │
│     Desktop / Web   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│    ASP.NET Core     │
│       .NET 9        │
│   Main Backend API  │
└─────────┬─────┬─────┘
          │     │
          ▼     ▼
     ┌────────┐ ┌────────────────┐
     │ Facial │ │ Recommendation │
     │ AI API │ │      AI API    │
     │ :8000  │ │      :8001     │
     └────────┘ └────────────────┘
```

### Technology Stack

| Layer            | Technology                                         |
| ---------------- | -------------------------------------------------- |
| Frontend         | Flutter / Dart                                     |
| Backend          | ASP.NET Core / .NET 9                              |
| AI Services      | Python / FastAPI                                   |
| Machine Learning | Facial Emotion Recognition + Recommendation Models |
| Email            | Gmail SMTP                                         |
| Desktop          | Flutter Linux                                      |
| Web              | Flutter Web                                        |

---

## Project Structure

```text
Echonova/
├── Echonova.Api/                       # .NET Backend
├── flutter/                            # Flutter Client
├── Emotion Detection AI Models/
│   ├── Facial Recognition System/      # Emotion AI
│   └── Music Recommendation System/   # Recommendation AI
├── scripts/
│   ├── start_all.sh
│   └── seed_playlists.sh
└── README.md
```

---

## Getting Started

### Requirements

* .NET 9 SDK
* Flutter 3.24+
* Dart 3.9+
* Python 3.10+

### Start Everything

```bash
./scripts/start_all.sh
```

This starts the AI services, .NET backend, and Flutter application.

By default, Flutter launches as a native Linux desktop application.

To run Flutter through Chrome:

```bash
FLUTTER_DEVICE=chrome ./scripts/start_all.sh
```

### Linux Dependencies

```bash
sudo apt-get install -y libgtk-3-dev libwebp-dev clang cmake ninja-build
```

---

## AI Services

### Facial Emotion Recognition

Runs on:

```text
http://localhost:8000
```

Endpoints:

```http
GET  /health
POST /emotion/predict
POST /emotion/predict-with-genres
```

The model can detect emotions such as **happy, sad, angry, fearful, neutral, surprised, and disgusted**.

### Music Recommendation

Runs on:

```text
http://localhost:8001
```

Endpoints:

```http
POST /recommend/by-title
POST /recommend/by-track-id
POST /recommend/from-multiple
```

---

## Email Recommendations

Echonova can automatically send personalized recommendation emails through Gmail SMTP.

Users can select:

**Off · Daily · Weekly · Monthly**

The system generates recommendations from listening history and can fall back to mood-based recommendations when applicable.

For development, configure Gmail SMTP using a Google App Password or .NET User Secrets.

---

## Development

The services can also be started individually:

```bash
# Facial AI
cd "Emotion Detection AI Models/Facial Recognition System"
.venv/bin/python -m uvicorn api:app --port 8000

# Recommendation AI
cd "Emotion Detection AI Models/Music Recommendation System"
.venv/bin/python -m uvicorn api:app --port 8001

# Backend
cd Echonova.Api
dotnet run

# Flutter
cd flutter
flutter pub get
flutter run -d linux
```

---

## Future Development

* Real-time song recognition
* More advanced recommendation models
* Hybrid and collaborative filtering
* Improved emotion recognition
* Automated playlist generation
* Listening analytics
* Android and iOS applications
* Real-time music playback
* Social music discovery

---

## Concept

Echonova is built around a simple idea:

> **Music recommendations shouldn't only understand what you usually listen to — they should understand what you might want to hear right now.**

By combining **listening behavior with emotional context**, Echonova aims to create a more personal and intelligent music discovery experience.
