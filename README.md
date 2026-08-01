# grok-md-reader

A markdown companion for Grok CLI on macOS. **Install once, then Cmd+click file paths on tool lines** — they open in the right app (MdReader for `.md`, Preview for PDF, …).

[中文说明 / Chinese version](README.zh-CN.md)

![Demo: open a markdown file from Grok CLI into MdReader](docs/assets/demo.gif)

---

## Why I built this

Coding agents produce markdown all day. The terminal shows raw text; I wanted Claude Desktop–style “click and read” for Grok CLI without teaching every agent a custom ritual.

## What you get

- **Install-and-click** — `./install.sh` builds **MdReader.app**, links the Grok plugin, and **sets macOS default apps** from one config (`.md` → MdReader, `.pdf` → Preview, Office when installed). Grok tool lines already emit `file://` links; Cmd+click uses system `open` → those defaults. **No agent cooperation required.**
- **MdReader.app** — native viewer (Swift + WKWebView), offline marked + highlight.js.
- **Fallback `/open` / `/preview`** — when the path is plain chat text (not a hyperlink) or the terminal ignores OSC-8.
- **Optional tracking** — hook records files the agent writes; History + hot refresh in the viewer.

## Install

Requirements: macOS, Grok CLI, Python 3, Xcode Command Line Tools (`swiftc`).

```bash
git clone https://github.com/yan-auto/grok-md-reader.git
cd grok-md-reader
./install.sh
```

That script:

1. Builds and installs `~/Applications/MdReader.app`
2. Links `~/.grok/plugins/md-reader`
3. Installs the side-channel tracking hook
4. **Applies OS default handlers** (skip with `./install.sh --no-set-defaults`)
5. Runs **doctor**

```bash
./install.sh --doctor          # re-check anytime
./install.sh --set-defaults    # re-apply defaults only
./install.sh --no-set-defaults # install without changing defaults
```

## How to open files

| Situation | What to do |
|-----------|------------|
| Path on a **tool line** (Write / Read / Edit) | **Cmd+click** the path |
| Path is **plain chat text** only | `/open /full/path` or ask the agent to open it |
| Terminal without OSC-8 (some Terminal.app setups) | `/open` / `/preview` |

**Out of scope:** arbitrary bare paths in chat bubbles are usually **not** hyperlinks. That is a Grok TUI limit, not a missing install step.

## Customize mapping

Single source: `plugins/md-reader/config/readers.example.json`.

Copy to `~/.grok/plugin-data/user/md-reader/readers.json` and edit `by_extension` / `apps` / `os_defaults.apply_extensions`. Then:

```bash
./install.sh --set-defaults
```

`/open` uses the same table via `open_path.py`.

## Tracking hook

```bash
touch ~/.grok/plugin-data/user/md-reader/hook_disabled   # off
rm    ~/.grok/plugin-data/user/md-reader/hook_disabled   # on
```

Silent side-channel only (last_path + history). Not required for Cmd+click.

## Design notes

Click bus = **OS defaults**. The plugin cannot intercept Grok’s `file://` opener; install stands on the OS side of that call. Details: [`docs/decisions/0002-os-defaults-install-and-click.md`](docs/decisions/0002-os-defaults-install-and-click.md), [`docs/`](docs/).

## Limits

- Viewer is macOS-only. Linux: plugin + `readers.json` / `xdg-open`.
- Chat plain-text paths are not clickable by design of the TUI.
- Install **does** change default apps for listed types unless you pass `--no-set-defaults`.

## License

MIT
