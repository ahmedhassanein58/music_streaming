#!/usr/bin/env bash
# Seed 5-10 playlists via the Echonova API. Requires: curl, an existing user account.
# Usage: ./seed_playlists.sh [BASE_URL] [EMAIL] [PASSWORD]
# Example: ./seed_playlists.sh http://localhost:5186 user@example.com mypassword

set -e
BASE_URL="${1:-http://localhost:5186}"
EMAIL="${2:-}"
PASSWORD="${3:-}"

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 [BASE_URL] EMAIL PASSWORD"
  echo "Example: $0 http://localhost:5186 user@example.com mypassword"
  exit 1
fi

echo "Logging in as $EMAIL..."
LOGIN_RESP=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

# Extract token (works without jq: look for "token":"...")
TOKEN=$(echo "$LOGIN_RESP" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$TOKEN" ]; then
  echo "Login failed. Response: $LOGIN_RESP"
  exit 1
fi
echo "Logged in."

PLAYLIST_NAMES="Rock Chill Workout Favorites Discover Party Focus Sleep Indie Acoustic"
for NAME in $PLAYLIST_NAMES; do
  echo "Creating playlist: $NAME"
  curl -s -X POST "$BASE_URL/playlists" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$NAME\"}" > /dev/null
done
echo "Created 10 playlists. Open the app and sign in to see them in Library."
