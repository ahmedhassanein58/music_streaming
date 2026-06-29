# How to Use This Project

Prerequisites: **.NET 9 SDK**, **Flutter 3.24+** (Dart 3.9+), and **Python 3.10+**.

## Quick start (all services)

From the project root:

```bash
./scripts/start_all.sh
```

This creates Python virtual environments, ensures model weights exist, and starts all four services. Flutter opens as a **native desktop window** (`flutter run -d linux`) by default—not in the browser.

Open the **Flutter desktop window** when it appears. If the build fails, install Linux desktop deps:

```bash
sudo apt-get install -y libgtk-3-dev libwebp-dev clang cmake ninja-build
```

To force browser mode instead: `FLUTTER_DEVICE=chrome ./scripts/start_all.sh`

---

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

---

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

---

## Install Python 3 (required for the AI services)

**Linux (Ubuntu/Debian/Kali):**

```bash
sudo apt-get update && sudo apt-get install -y python3 python3-venv python3-pip
python3 --version
```

Use a **virtual environment** per service (recommended on Kali/Debian):

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

---

## Facial Emotion Model Weights

The facial recognition service needs `model_weights.weights.h5` beside `model.json`.

**First-time setup (placeholder weights — API starts, predictions improve after training):**

```bash
cd "Emotion Detection AI Models/Facial Recognition System"
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python create_placeholder_weights.py
```

**Full training (recommended for accurate mood detection, ~30–60 min on CPU):**

```bash
cd "Emotion Detection AI Models/Facial Recognition System"
.venv/bin/pip install kagglehub
.venv/bin/python train_model.py --epochs 70
```

This downloads the Kaggle face-expression dataset and saves trained weights to `model_weights.weights.h5`.

---

## Python FastAPI Services

Both ML services must be running before emotion scan and ML recommendations work.

### Service 1 — Facial Emotion Recognition (port 8000)

Located in: `Emotion Detection AI Models/Facial Recognition System/`

```bash
cd "Emotion Detection AI Models/Facial Recognition System"
python3 -m venv .venv   # first time only
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m uvicorn api:app --port 8000
```

Endpoints:
- `GET /health` — service and model status
- `POST /emotion/predict` — emotion only
- `POST /emotion/predict-with-genres` — emotion + mapped music genres

The .NET backend calls these via `POST /emotion/scan` (Flutter Mood Scan page).

---

### Service 2 — Music Recommendation System (port 8001)

Located in: `Emotion Detection AI Models/Music Recommendation System/`

```bash
cd "Emotion Detection AI Models/Music Recommendation System"
python3 -m venv .venv   # first time only
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m uvicorn api:app --port 8001
```

Endpoints:
- `POST /recommend/by-title`
- `POST /recommend/by-track-id`
- `POST /recommend/from-multiple`

---

## Gmail Setup (Recommendation Emails)

Echonova sends welcome and recommendation emails via **Gmail SMTP** using a Google **App Password**.

### What you need from your Google account

1. **Gmail address** (e.g. `you@gmail.com`)
2. **App Password** (16 characters) — not your regular Gmail password

### Create an App Password

1. Enable **2-Step Verification** on your Google account
2. Go to [Google App Passwords](https://myaccount.google.com/apppasswords)
3. Create a password for "Mail" / "Other (Echonova)"
4. Copy the 16-character password

### Configure the backend

Edit `Echonova.Api/appsettings.Development.json` (or use user secrets):

```json
"Smtp": {
  "Host": "smtp.gmail.com",
  "Port": 587,
  "UseSsl": false,
  "Username": "YOUR_GMAIL@gmail.com",
  "Password": "YOUR_16_CHAR_APP_PASSWORD",
  "FromAddress": "YOUR_GMAIL@gmail.com",
  "FromName": "Echonova"
}
```

**User secrets (keeps credentials out of git):**

```bash
cd Echonova.Api
dotnet user-secrets set "Smtp:Username" "YOUR_GMAIL@gmail.com"
dotnet user-secrets set "Smtp:Password" "YOUR_APP_PASSWORD"
dotnet user-secrets set "Smtp:FromAddress" "YOUR_GMAIL@gmail.com"
```

You do **not** need Google Cloud Console, OAuth, or Gmail API keys.

### Email features in the app

- **Welcome email** — sent on signup
- **Recommendation digests** — user chooses frequency in Profile: Off / Daily / Weekly / Monthly
- Emails use ML recommendations from play history, with mood-based fallback when available

---

## Run (manual — four terminals)

**Terminal 1 — Facial Emotion API:**

```bash
cd "Emotion Detection AI Models/Facial Recognition System"
.venv/bin/python -m uvicorn api:app --port 8000
```

**Terminal 2 — Music Recommendation API:**

```bash
cd "Emotion Detection AI Models/Music Recommendation System"
.venv/bin/python -m uvicorn api:app --port 8001
```

**Terminal 3 — .NET backend API:**

```bash
cd Echonova.Api && dotnet run
```

**Terminal 4 — Flutter app (native desktop window):**

```bash
cd flutter && flutter pub get && flutter run -d linux
```

> On first Linux desktop run, install build deps if needed:
> `sudo apt-get install -y libgtk-3-dev libwebp-dev clang cmake ninja-build`

> The .NET API works without Python services, but Mood Scan and ML suggestions will be limited.

---

## New features

| Feature | Where |
|---------|--------|
| **Mood Scan** | Home → "Scan Your Mood" card, or `/mood-scan` |
| **Emotion → genre recs** | Detects happy/sad/angry/etc. and recommends matching genres |
| **Email frequency** | Profile → Daily / Weekly / Monthly / Off |
| **Scheduled emails** | Backend sends digests automatically (checks every hour) |

---

## Seed playlists (optional)

1. Sign up or log in once in the app.
2. Run:

```bash
cd scripts && ./seed_playlists.sh http://localhost:5186 YOUR_EMAIL YOUR_PASSWORD
```

See `scripts/README.md` for details.

---

## Verification checklist

- [ ] `curl http://localhost:8000/health` returns `"model_ready": true`
- [ ] Mood Scan detects emotion and shows song recommendations
- [ ] Home "Suggested for you" works when logged in with play history
- [ ] Profile saves email frequency
- [ ] Welcome email arrives after signup (with Gmail configured)
- [ ] Recommendation email arrives after the chosen interval
