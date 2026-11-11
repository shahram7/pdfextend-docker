# PDFextend Docker

A Docker image for [PDFextend](https://github.com/DorianRudolph/pdfextend) by
[@DorianRudolph](https://github.com/DorianRudolph): add margins with grid lines
for annotation to a PDF document.

The image builds the upstream web app (Rust → WASM + React) and serves the
static result with nginx.

## Run

```bash
docker run -d \
  -p 1080:80 \
  --name pdfextend \
  --restart unless-stopped \
  shahram7/pdfextend:latest
```

Open <http://localhost:1080>.

If your Docker Hub username is not `shahram7`, replace it above or use the image
you pushed.

## Docker Compose

```yaml
services:
  pdfextend:
    image: shahram7/pdfextend:latest
    container_name: pdfextend
    ports:
      - "1080:80"
    restart: unless-stopped
```

## Build locally

```bash
docker build -t shahram7/pdfextend:latest .
docker run --rm -p 1080:80 shahram7/pdfextend:latest
```

The build is pinned to:

- upstream commit `c53db44affaf5be5accdaccd8f8d5d28bf3de28d`
- PDFium WASM release `8046d` from
  [paulocoutinhox/pdfium-lib](https://github.com/paulocoutinhox/pdfium-lib)

Both are build args at the top of the `Dockerfile`. When bumping the PDFium
version, update its SHA-256 checksum too.

## Why the PDFium bundle matters

The upstream worker (`webapp/public/worker.js`) calls a global
`PDFiumModule()` factory:

```js
importScripts('pdfium.js', 'pdfextend_web.js');
const loaded = PDFiumModule().then(async (pdfiumModule) => { ... });
```

Only the `paulocoutinhox/pdfium-lib` WASM build provides that factory.
`bblanchon/pdfium-binaries` provides a classic Emscripten `Module` instead, so
using it makes the worker fail with:

```text
Uncaught ReferenceError: PDFiumModule is not defined
```

The **Extend!** button then stays disabled forever. The `Dockerfile` extracts
`release/node/pdfium.js` and `release/node/pdfium.wasm` from the pinned
`wasm.zip` and verifies that `PDFiumModule` is present before the image is
published.

## GitHub Actions

`.github/workflows/build.yml` builds and pushes the image on:

- pushes to `main`
- tags matching `v*`
- manual runs (`workflow_dispatch`)
- a weekly schedule

To publish immediately after committing the workflow, open **Actions →
Build and push Docker image → Run workflow**.

### Required repository secrets

| Secret | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | A Docker Hub access token with **Read & Write** permission |

The workflow pushes to:

```text
${{ secrets.DOCKERHUB_USERNAME }}/pdfextend
```

### Recommended Docker Hub settings

- The repository is created automatically on the first push, but it may be
  **private** by default. If anonymous users get `pull access denied`, open
  Docker Hub → Repositories → `pdfextend` → Settings → Visibility and set it to
  **Public**.
- The token must have write access; a read-only token makes the login succeed
  but the push fail.

### If the schedule stops

GitHub disables scheduled workflows after 60 days of repository inactivity.
Open the **Actions** tab, select the workflow, and click **Enable workflow** if
it is disabled.

## Notes

- The app uses absolute paths (`/favicon.svg`, `new Worker('worker.js')`), so it
  must be served at the root of a hostname. If you put it behind a reverse proxy
  on a subpath such as `/pdfextend/`, rebuild the frontend with a matching Vite
  `base` and adjust the worker URL.
- The PWA service worker only registers on HTTPS or `localhost`; on a plain HTTP
  LAN address the app still works, but offline caching does not.
- PDFextend is licensed under AGPL-3.0. All credit for the application goes to
  Dorian Rudolph; this repository only packages the web build.

## Troubleshooting

- **`pull access denied` / `repository does not exist`**: the Docker Hub
  repository is private or the username in the workflow secret is not the one
  in the `docker run` command. Make the repository public or run
  `docker login` first.
- **The app loads, but `Extend!` stays disabled and the preview never
  appears**: open DevTools → Console. If you see
  `Uncaught ReferenceError: PDFiumModule is not defined`, the image was built
  with the wrong PDFium bundle. Rebuild with this `Dockerfile`.
- **The weekly workflow stopped running**: GitHub disables scheduled workflows
  after 60 days without repository activity. Re-enable it from the Actions tab.
