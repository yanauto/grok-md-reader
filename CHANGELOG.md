# Changelog

## 0.3.0 — 2026-07-26

Open-source release (Phase 4).

- English community README + Chinese `README.zh-CN.md`
- One-shot installer: `./install.sh`
- Demo GIF: `docs/assets/demo.gif`
- Plugin / marketplace version aligned to **0.3.0**

## 0.2.0 — 2026-07-26

Phase 3 delivery loop.

- Side-channel `PostToolUse` hook → `last_path` + session history
- MdReader hot-reload (DispatchSource) + History menu
- Global hook install script (reliable path when plugin hooks do not register)

## 0.1.0 — 2026-07-26

Phase 0–2 skeleton and viewer MVP.

- Plugin commands `/open` `/preview`, skill `open-md`
- MdReader.app (Swift + WKWebView, offline marked/hljs)
- URL scheme `md-reader://`
