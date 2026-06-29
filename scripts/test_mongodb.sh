#!/usr/bin/env bash
# Test MongoDB Atlas connectivity using the configured connection string.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/Emotion Detection AI Models/Facial Recognition System/.venv"

if [[ -n "${MONGODB_URI:-}" ]]; then
  URI="$MONGODB_URI"
else
  URI=$(python3 - <<'PY'
import json, pathlib
p = pathlib.Path("Echonova.Api/appsettings.Development.json")
data = json.loads(p.read_text())
print(data["MongoDb"]["ConnectionString"])
PY
)
fi

cd "$ROOT"
if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q pymongo dnspython
fi

echo "Testing MongoDB connection..."
"$VENV/bin/python" <<PY
from pymongo import MongoClient
uri = """$URI"""
client = MongoClient(uri, serverSelectionTimeoutMS=20000)
client.admin.command("ping")
print("MongoDB ping: OK")
db = client.get_default_database() if "/" in uri.split("mongodb.net")[-1] else client["echonova"]
try:
    name = db.name
except Exception:
    name = "echonova"
    db = client[name]
print(f"Database: {name}")
print("Collections:", db.list_collection_names())
PY
