# Web-application-in-Elm

## Prerequisites

- elm 0.19.1
- nodejs 0.16+

## Setup

1. In `backend`, run `mix setup`.
2. Run `npm install` to install Elm dependencies.
3. Clouseau must be running to do searches.  Install it with the `install_clouseau.sh` script in the root folder.

## Development

Use `npm run start` to start frontend and backend and Clouseau.

Go to `http://localhost:4000`.

### Dev notes

- If `http://localhost:3000` ever changes, then the credentials in Google's Cloud Console will need to be modified to add the changed URL.  If the changed URL isn't on `localhost`, then it'll need to be served via HTTPS.
- If any non-Elm component changes (e.g. CSS, HTML, JS), you'll need to do a manual reload.  `elm-watch` does what it says on the can: it watches Elm files and triggers hot-reload if they change.  It doesn't watch anything else!