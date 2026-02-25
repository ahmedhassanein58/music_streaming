# Echonova API

.NET 9 Web API for the Echonova music recommendation backend. Uses MongoDB, JWT auth, PBKDF2-SHA256 passwords, MailKit for email, and AWS S3 for song uploads.

## Run

```bash
dotnet run
```

Set `appsettings.json` (or environment variables) for:

- **MongoDb**: `ConnectionString`, `DatabaseName`
- **Jwt**: `Secret` (min 32 chars for HS256), `Issuer`, `Audience`, `ExpirationMinutes`
- **Smtp**: `Host`, `Port`, `Username`, `Password`, `FromAddress`, `FromName`
- **Aws**: `AccessKeyId`, `SecretAccessKey`, `BucketName`, `Region`

Seed the `admins` collection manually with an admin document (email + PBKDF2-SHA256 password hash). Admin login uses the same `POST /auth/login`; the API sets `isAdmin` in the JWT when the email exists in `admins`.

## Endpoints

- **Auth**: `POST /auth/signup`, `POST /auth/login`, `POST /auth/send-otp`, `POST /auth/verify-otp`
- **Users**: `GET /users/me`, `PATCH /users/me` (Bearer)
- **Songs**: `GET /songs`, `GET /songs/{trackId}` (public)
- **Playlists**: `GET/POST /playlists`, `GET/PATCH/DELETE /playlists/{id}`, `POST /playlists/{id}/tracks`, `DELETE /playlists/{id}/tracks/{trackId}` (Bearer)
- **History**: `GET /history`, `POST|PUT /history` (Bearer)
- **Anonymous**: `POST /anonymous/session`
- **Admin** (Bearer + `isAdmin`): `GET/POST /admin/songs`, `POST /admin/songs/upload`, `PUT/DELETE /admin/songs/{trackId}`, `GET/POST /admin/users`, `POST /admin/recommendations/send-now`
