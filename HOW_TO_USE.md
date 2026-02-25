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

## Run

**Terminal 1 — start API:**

```bash
cd Echonova.Api && dotnet run
```

**Terminal 2 — start app:**

```bash
cd flutter && flutter pub get && flutter run -d web-server --web-port=8080 
```

## Seed playlists (optional)

To create sample playlists (e.g. Rock, Chill, Workout) so the Library has data:

1. Sign up or log in once in the app so your user exists.
2. From the project root, run:

```bash
cd music_streaming/scripts && ./seed_playlists.sh http://localhost:5186 YOUR_EMAIL YOUR_PASSWORD
```

See `scripts/README.md` for details.
