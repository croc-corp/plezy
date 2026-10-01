# Plezy for the browser

`scripts/web/build.sh` builds an installable Flutter PWA in `build/web`. It
uses Flutter's WASM target with a JavaScript fallback, and includes SQLite's
WASM runtime and hls.js locally. The browser bundle is architecture-independent,
so an ARM Chromebook can run a bundle built on another machine.

## Build

From the repository root:

```sh
scripts/web/build.sh
scripts/web/package.sh
```

The first script downloads the Flutter version pinned by upstream CI into
`~/.cache/plezy-web` unless `FLUTTER` names a Flutter binary. It produces
`build/web`. The second creates `build/plezy-web.zip` for transfer to a
Chromebook. To build for a subpath on an HTTPS host, pass
`--base-href /your-path/` to `build.sh`.

For iterative work, use `scripts/web/dev.sh --port 8081`. That serves a debug
JavaScript build; the release script is the WASM check.

## Run and install on an ARM Chromebook

Enable the Chromebook's Linux development environment, copy
`build/plezy-web.zip` into it, and run:

```sh
unzip plezy-web.zip
cd plezy-web
sh run.sh
```

In ChromeOS Chrome, open `http://localhost:8080/`. [ChromeOS forwards Linux
localhost ports](https://chromeos.dev/en/web-environment) into the main browser.
After opening the app, use Chrome's
**Install Plezy** action in the address bar or the browser menu. Keep `run.sh`
running for reliable launches and updates; the installed PWA launches from
the same localhost origin. Its cached shell can load offline, while media and
library content still require access to your Plex, Jellyfin, or Emby server.

For another device or permanent hosting, serve `build/web` over HTTPS. A LAN
HTTP URL is not a secure context, so it cannot register this PWA's service
worker. The media server must allow browser cross-origin requests from the
chosen app origin. Browser video playback uses URL tokens because HTML video
and hls.js cannot attach Plezy's native HTTP headers. Plex and Jellyfin
transcoding is requested for browser-compatible H.264/AAC HLS when needed.

`.github/workflows/pages.yml` builds `main` on every push and deploys it to
GitHub Pages. Enable it once under **Settings → Pages** by setting the source
to **GitHub Actions**.

## Scope

Browser playback supports HTML video, HLS transcoding, seeking, volume, speed,
and URL-based text subtitle files. Native-only features such as offline media
downloads, audio passthrough, hardware display-mode switching, native media
controls, and advanced mpv filters are unavailable in the browser.
