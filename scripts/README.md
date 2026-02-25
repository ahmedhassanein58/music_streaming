# Scripts

## seed_playlists.sh

Creates 10 playlists (Rock, Chill, Workout, Favorites, Discover, Party, Focus, Sleep, Indie, Acoustic) via the API.

**Requirements:** API running, and an existing user account (sign up in the app first).

**Usage:**

```bash
./seed_playlists.sh [BASE_URL] EMAIL PASSWORD
```

**Example:**

```bash
./seed_playlists.sh http://localhost:5186 user@example.com mypassword
```

Then open the app, sign in, and go to Library → Playlists to see the new playlists.
