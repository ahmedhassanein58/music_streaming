# How to Use This Project

Prerequisites: **.NET 9 SDK** and **Flutter 3.24+** (Dart 3.9+). Install then run with the commands below.

## Install .NET 9 SDK

**Linux (Ubuntu/Debian):**

```bash
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y dotnet-sdk-9.0
dotnet --version
```
**Windows (PowerShell):**

```powershell
winget install Microsoft.DotNet.SDK.9
```

## Install Flutter (3.24 or later — Dart 3.9+)

**Linux (snap):**

```bash
sudo snap install flutter --classic
flutter --version
```

**Windows (PowerShell):**

```powershell
winget install Google.Flutter
flutter --version
```

Check that you have Flutter 3.24+ and Dart 3.9+:

```bash
flutter --version
```

## Install Python 3 (required for the AI services)

The two ML micro-services require **Python 3.10+** and `pip`.

**Linux (Ubuntu/Debian):**

```bash
sudo apt-get update && sudo apt-get install -y python3 python3-pip
python3 --version
```

**Windows (PowerShell):**

```powershell
winget install Python.Python.3
```

---

## Python FastAPI Services

The project includes two independent FastAPI services that the .NET backend calls internally.
Both must be running before you start the main API.

### Service 1 — Facial Emotion Recognition (port 8000)

Located in: `Emotion Detection AI Models/Facial Recognition System/`

**Install dependencies:**

```bash
cd "Emotion Detection AI Models/Facial Recognition System"
pip install -r requirements.txt
```

> **Note:** `tensorflow` is a large package (~500 MB). Installation may take a few minutes.
> If you are on an Apple Silicon Mac use `pip install tensorflow-macos` instead.

**Start the service:**

```bash
python3 -m uvicorn api:app --port 8000
```

The service will be available at `http://localhost:8000`.
Endpoint used by the backend: `POST /emotion/predict` (multipart image upload).

---

### Service 2 — Music Recommendation System (port 8001)

Located in: `Emotion Detection AI Models/Music Recommendation System/`

**Install dependencies:**

```bash
cd "Emotion Detection AI Models/Music Recommendation System"
pip install -r requirements.txt
```

**Start the service:**

```bash
python3 -m uvicorn api:app --port 8001
```

The service will be available at `http://localhost:8001`.
Endpoints used by the backend:
- `POST /recommend/by-title` — recommendations based on a song title
- `POST /recommend/by-track-id` — recommendations based on a track ID
- `POST /recommend/from-multiple` — recommendations blended from several track IDs

---

## Run

Start all four services in separate terminals **in this order**:

**Terminal 1 — Facial Emotion API:**

```bash
cd "Emotion Detection AI Models/Facial Recognition System"
python3 -m uvicorn api:app --port 8000
```

**Terminal 2 — Music Recommendation API:**

```bash
cd "Emotion Detection AI Models/Music Recommendation System"
python3 -m uvicorn api:app --port 8001
```

**Terminal 3 — .NET backend API:**

```bash
cd Echonova.Api && dotnet run
```

**Terminal 4 — Flutter app:**

```bash
cd flutter && flutter pub get && flutter run -d web-server --web-port=8080
```

> The .NET API and Flutter app will work without the Python services running,
> but emotion detection and personalised recommendations will be unavailable.

## Seed playlists (optional)

To create sample playlists (e.g. Rock, Chill, Workout) so the Library has data:

1. Sign up or log in once in the app so your user exists.
2. From the project root, run:

```bash
cd music_streaming/scripts && ./seed_playlists.sh http://localhost:5186 YOUR_EMAIL YOUR_PASSWORD
```

See `scripts/README.md` for details.
