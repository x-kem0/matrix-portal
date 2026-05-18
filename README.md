# Misskey Matrix Registration Portal

## Environment Variables
The following environment variables are *required*: 

### `MISSKEY_HOST`
- The user-accessible misskey server URL'
- Example: `https://kemokemo.org`
---
### `MISSKEY_NAME`
- User friendly name of the instance
- Example: `Kemokemo`

---
### `MATRIX_HOST`
- URL for your Matrix homeserver
- Example: `https://matrix.kemokemo.org` / `http://127.0.0.1:8448`

---
### `MATRIX_CLIENT`
- URL redirect for your Matrix client upon registration
- Example: `https://matrix.kemokemo.org`

---
### `MATRIX_DELEGATE`
- The delegated name for your matrix server
- Example: `kemokemo.org`

---
### `MATRIX_ADMIN_USER`
- A matrix administrator user account name
- Example: `admin`

---
### `MATRIX_ADMIN_PASS`
- A matrix administrator user account password
- Example: `supersecure1`

---
### `MATRIX_PSK`: 
- `registration_shared_secret` as specified in your `homeserver.yml`
---
### `MATRIX_JOINS`
- Spaces and rooms to automatically join upon user registration, separated by spaces
- Example: `#kemokemo:kemokemo.org #general:kemokemo.org`
---
### `APP_HOST`
- User accessible URL for this application, used for redirect
- Example: `https://join.matrix.kemokemo.org`
---
### `APP_NAME` 
- User friendly name for this application
- Example: `Kemokemo Matrix Portal`
---
### `APP_ICON_URL` 
- URL for application icon image used in Misskey
- Example: `https://example.com/logo.png`
---
### `SECRET_KEY_BASE` 
- 32-64 character long secret key base required by Phoenix framework
- A suitable key can be generated via `openssl rand -base64 48`
- Example: `jGqiZu8wer7iwLRplfANmDowBt3KBnUHTJh+cE/7/cwAuwRLtF51QAorS6dj0TEb`