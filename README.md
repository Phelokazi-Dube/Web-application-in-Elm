# Web-application-in-Elm

## Prerequisites

- elm 0.19.1
- nodejs 0.16+

## Development

Run `npm install`, which should install both `elm-watch` and `serve`.  Then:

1. In one terminal, run `npx elm-watch hot` for hot-reloading.
2. In another terminal, run `npx serve` for serving via HTTP.  (you need to do this because we use Google for auth, and Google auth does not like working from `file://` URLs).
3. Go to `http://localhost:3000`.

### Dev notes

- If `http://localhost:3000` ever changes, then the credentials in Google's Cloud Console will need to be modified to add the changed URL.  If the changed URL isn't on `localhost`, then it'll need to be served via HTTPS.
- If any non-Elm component changes (e.g. CSS, HTML, JS), you'll need to do a manual reload.  `elm-watch` does what it says on the can: it watches Elm files and triggers hot-reload if they change.  It doesn't watch anything else!