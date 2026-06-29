#!/usr/bin/env bash
# Run Echonova Flutter app as a native desktop window (not in the browser).
set -euo pipefail
cd "$(dirname "$0")/../flutter"
flutter pub get
flutter run -d linux "$@"
