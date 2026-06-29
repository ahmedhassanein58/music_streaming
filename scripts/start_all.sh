#!/usr/bin/env bash
# Start all Echonova services (facial AI, music rec AI, .NET API, Flutter web app).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FACIAL_DIR="$ROOT/Emotion Detection AI Models/Facial Recognition System"
REC_DIR="$ROOT/Emotion Detection AI Models/Music Recommendation System"
API_DIR="$ROOT/Echonova.Api"
FLUTTER_DIR="$ROOT/flutter"

FACIAL_PORT=8000
REC_PORT=8001
API_PORT=5186
# Default: browser (Chrome/Chromium). Override with FLUTTER_DEVICE=linux for native desktop.
FLUTTER_DEVICE="${FLUTTER_DEVICE:-chrome}"
# Kali/Linux often has Chromium at /usr/bin/chromium instead of google-chrome
if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
  for candidate in /usr/bin/google-chrome /usr/bin/google-chrome-stable /usr/bin/chromium /usr/bin/chromium-browser; do
    if [[ -x "$candidate" ]]; then
      export CHROME_EXECUTABLE="$candidate"
      break
    fi
  done
fi

log() { echo "[start_all] $*"; }

check_flutter_linux_deps() {
  if [[ "$FLUTTER_DEVICE" != "linux" ]]; then
    return 0
  fi
  if [[ -d /usr/include/webp ]]; then
    return 0
  fi
  log "ERROR: Flutter Linux desktop build requires libwebp-dev (missing /usr/include/webp)"
  log "Fix: sudo ./scripts/install_flutter_linux_deps.sh"
  log "  or: sudo apt-get install -y libwebp-dev libgtk-3-dev clang cmake ninja-build"
  exit 1
}

wait_for_url() {
  local url="$1"
  local name="$2"
  local tries="${3:-30}"
  for i in $(seq 1 "$tries"); do
    if curl -sf "$url" >/dev/null 2>&1; then
      log "$name is up ($url)"
      return 0
    fi
    sleep 1
  done
  log "WARNING: $name did not respond at $url"
  return 1
}

# Ensure Python venvs exist
if [[ ! -d "$FACIAL_DIR/.venv" ]]; then
  log "Creating facial recognition venv..."
  python3 -m venv "$FACIAL_DIR/.venv"
  "$FACIAL_DIR/.venv/bin/pip" install -r "$FACIAL_DIR/requirements.txt"
fi
if [[ ! -f "$FACIAL_DIR/model_weights.weights.h5" ]]; then
  log "Creating placeholder model weights (run train_model.py for real accuracy)..."
  "$FACIAL_DIR/.venv/bin/python" "$FACIAL_DIR/create_placeholder_weights.py"
fi
if [[ ! -d "$REC_DIR/.venv" ]]; then
  log "Creating music recommendation venv..."
  python3 -m venv "$REC_DIR/.venv"
  "$REC_DIR/.venv/bin/pip" install -r "$REC_DIR/requirements.txt"
fi

log "Starting Facial Emotion API on :$FACIAL_PORT"
(cd "$FACIAL_DIR" && .venv/bin/python -m uvicorn api:app --port "$FACIAL_PORT") &
FACIAL_PID=$!

log "Starting Music Recommendation API on :$REC_PORT"
(cd "$REC_DIR" && .venv/bin/python -m uvicorn api:app --port "$REC_PORT") &
REC_PID=$!

wait_for_url "http://localhost:$FACIAL_PORT/health" "Facial API" || true
wait_for_url "http://localhost:$REC_PORT/docs" "Music Rec API" || true

log "Starting .NET API on :$API_PORT"
(cd "$API_DIR" && dotnet run) &
API_PID=$!
wait_for_url "http://localhost:$API_PORT/swagger/index.html" ".NET API" || true

check_flutter_linux_deps

if [[ "$FLUTTER_DEVICE" == "linux" ]]; then
  log "Starting Flutter app (Linux desktop)"
  (cd "$FLUTTER_DIR" && flutter pub get && flutter run -d linux) &
else
  log "Starting Flutter app in browser on :8080"
  (
    cd "$FLUTTER_DIR"
    flutter pub get
    if flutter devices 2>/dev/null | grep -qE 'Chrome|chrome'; then
      flutter run -d chrome --web-port=8080
    else
      flutter run -d web-server --web-port=8080 --web-hostname=localhost &
      FLUTTER_WEB_PID=$!
      for i in $(seq 1 90); do
        if curl -sf "http://localhost:8080/" >/dev/null 2>&1; then
          xdg-open "http://localhost:8080" 2>/dev/null \
            || sensible-browser "http://localhost:8080" 2>/dev/null \
            || "${CHROME_EXECUTABLE:-/usr/bin/chromium}" "http://localhost:8080" 2>/dev/null \
            || true
          break
        fi
        sleep 1
      done
      wait "$FLUTTER_WEB_PID"
    fi
  ) &
fi
FLUTTER_PID=$!

log "All services launched."
if [[ "$FLUTTER_DEVICE" == "linux" ]]; then
  log "  Flutter app:  desktop window (-d linux)"
else
  log "  Flutter app:  http://localhost:8080 (browser)"
fi
log "  .NET API:     http://localhost:$API_PORT/swagger"
log "  Facial API:   http://localhost:$FACIAL_PORT/docs"
log "  Music Rec:    http://localhost:$REC_PORT/docs"
log ""
log "Press Ctrl+C to stop all services."

cleanup() {
  log "Stopping services..."
  kill "$FACIAL_PID" "$REC_PID" "$API_PID" "$FLUTTER_PID" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

wait
