# grok-md-reader

A markdown companion for Grok CLI on macOS. Your agent writes a `.md` file, and a native window shows it fully rendered — tables, code highlighting, the lot.

[中文说明 / Chinese version](README.zh-CN.md)

![Demo: open a markdown file from Grok CLI into MdReader](docs/assets/demo.gif)

---

## Why I built this

I run coding agents in a terminal most of the day, and they produce markdown constantly: reports, plans, research notes. The terminal shows all of that as raw text. Every time I wanted to actually read a document, I had to dig it out of Finder or open an editor, and after a few weeks of that I got tired of it.

Claude Desktop handles this nicely: the session hands you a file, you click it, you read it rendered. I wanted the same flow for Grok CLI, so I built it as a plugin plus a tiny viewer app.

## What you get

- **MdReader.app** — a small native viewer (Swift + WKWebView) with bundled marked and highlight.js. It renders offline; nothing leaves your machine.
- **A Grok plugin** — `/open <path>` and `/preview` commands, plus a skill so the agent itself can open a file for you when you ask.
- **Automatic tracking** — a `PostToolUse` hook records every markdown file the agent writes during a session. `/preview` opens the most recent one, and the History button in the viewer switches between all of them.
- **Hot refresh** — while a file is open, the viewer watches it. When the agent keeps editing, the window re-renders on its own. When the file disappears, the viewer degrades gracefully.
- **Click to open** — Grok's tool lines carry `file://` hyperlinks. Set MdReader as your default app for `.md` and Cmd+clicking any written path opens it rendered.

## Install

Requirements: macOS, Grok CLI, Python 3, Xcode Command Line Tools (`swiftc`).

```bash
git clone https://github.com/yan-auto/grok-md-reader.git
cd grok-md-reader
./install.sh
```

That single script builds **MdReader.app**, links the Grok plugin, and installs the tracking hook. Equivalent manual steps live in [`install.sh`](install.sh) if you prefer to run them one by one.

Check that everything landed:

```bash
grok inspect        # Plugins → md-reader
python3 plugins/md-reader/skills/open-md/scripts/open_path.py README.md
# a MdReader window should pop up

# after an agent writes a .md in a new session:
cat ~/.grok/plugin-data/user/md-reader/last_path
```

## Click to open (optional, recommended)

Grok's TUI already emits `file://` hyperlinks on its Write/Edit tool lines. To make those clicks land in MdReader:

1. Select any `.md` file in Finder and press ⌘I.
2. Under "Open with", choose **MdReader**, then click **Change All…**.

From then on, Cmd+click on a written path in the session opens the rendered document. The install scripts never touch your default apps; this step stays manual on purpose.

One dependency to know about: clickable paths rely on your terminal's OSC-8 hyperlink support. iTerm2 and Ghostty handle it with Cmd+click. The built-in Terminal.app ignores these links — `/open` and `/preview` cover that case.

## Turning the tracking hook off

```bash
touch ~/.grok/plugin-data/user/md-reader/hook_disabled   # off
rm    ~/.grok/plugin-data/user/md-reader/hook_disabled   # on
# or set MD_READER_HOOK_DISABLE=1
```

The hook writes two small local files (`last_path` and a per-session history list) and produces no visible output in your session.

## Using a different viewer

`config/readers.example.json` maps file extensions to apps. Copy it to `$GROK_PLUGIN_DATA/readers.json` and point `.md` at `system`, `typora`, `vscode`, or any app you like. MdReader is the default.

## Design notes

The viewer and the plugin are deliberately separate: they talk through the `md-reader://` URL scheme, so either side can be replaced or upgraded on its own. The hook stays silent because Grok ignores stdout from passive hooks — I verified this against the grok-build source before settling on the design. The full design history lives in [`docs/`](docs/) (written in Chinese): probe experiments, source findings, and the reasoning behind each phase.

## Limits

- The viewer is macOS-only for now. On Linux the plugin still works with `readers.json` mapped to `xdg-open` or an app of your choice.
- Clicking arbitrary file names in chat text is out of scope; the hyperlinks live on tool lines.
- Workspace-boundary enforcement (refusing to open files outside the project) is on the roadmap.

## License

MIT
