#!/usr/bin/env python3
"""Generate docs/assets/demo.gif — storyboard of agent write → MdReader open.

No screen-recording permission required; draws a simple two-pane mock.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

W, H = 960, 540
OUT = Path(__file__).resolve().parents[1] / "docs" / "assets" / "demo.gif"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Menlo.ttc",
    ]
    for p in candidates:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            continue
    return ImageFont.load_default()


def rounded(draw: ImageDraw.ImageDraw, box, fill, radius=12):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def frame_terminal(title: str, lines: list[tuple[str, str]]) -> Image.Image:
    """lines: list of (color, text)"""
    img = Image.new("RGB", (W, H), "#1a1b1e")
    d = ImageDraw.Draw(img)
    # window chrome
    rounded(d, (24, 24, W - 24, H - 24), "#0d1117", 16)
    d.ellipse((44, 44, 62, 62), fill="#ff5f56")
    d.ellipse((72, 44, 90, 62), fill="#ffbd2e")
    d.ellipse((100, 44, 118, 62), fill="#27c93f")
    d.text((140, 42), title, fill="#8b949e", font=font(16))
    y = 90
    mono = font(18)
    for color, text in lines:
        d.text((48, y), text, fill=color, font=mono)
        y += 28
    return img


def frame_viewer() -> Image.Image:
    img = Image.new("RGB", (W, H), "#1a1b1e")
    d = ImageDraw.Draw(img)
    # left: terminal strip
    rounded(d, (24, 24, 360, H - 24), "#0d1117", 14)
    d.ellipse((40, 40, 54, 54), fill="#ff5f56")
    d.ellipse((62, 40, 76, 54), fill="#ffbd2e")
    d.ellipse((84, 40, 98, 54), fill="#27c93f")
    d.text((40, 72), "Grok CLI", fill="#8b949e", font=font(14))
    mono = font(15)
    term_lines = [
        ("#8b949e", "$ /open report.md"),
        ("#3fb950", "opened (md-reader)"),
        ("#8b949e", ""),
        ("#8b949e", "Write  report.md"),
        ("#58a6ff", "  (hot-reload)"),
    ]
    y = 110
    for c, t in term_lines:
        d.text((40, y), t, fill=c, font=mono)
        y += 24

    # right: MdReader
    rounded(d, (380, 24, W - 24, H - 24), "#ffffff", 14)
    d.rectangle((380, 24, W - 24, 64), fill="#f6f8fa")
    d.text((400, 34), "MdReader  —  report.md", fill="#24292f", font=font(16, bold=True))
    d.text((W - 160, 36), "History ▾", fill="#57606a", font=font(14))

    body = [
        ("#1f2328", 28, True, "Release notes"),
        ("#57606a", 16, False, ""),
        ("#1f2328", 18, False, "• Tables and code highlighting"),
        ("#1f2328", 18, False, "• Hot refresh while the agent edits"),
        ("#1f2328", 18, False, "• Session history in the toolbar"),
        ("#57606a", 16, False, ""),
        ("#1f2328", 16, False, "def open_path(p: Path) -> None:"),
        ("#0550ae", 16, False, "    viewer.open(p)  # md-reader://"),
    ]
    y = 88
    for color, size, bold, text in body:
        if not text:
            y += 10
            continue
        d.text((400, y), text, fill=color, font=font(size, bold=bold))
        y += size + 10

    # status bar
    d.rectangle((380, H - 56, W - 24, H - 24), fill="#f6f8fa")
    d.text((400, H - 48), "watching · hot-reload", fill="#1a7f37", font=font(14))
    return img


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    f1 = frame_terminal(
        "Grok CLI · session",
        [
            ("#8b949e", "agent ▸ writing report.md …"),
            ("#3fb950", "Write  /project/report.md"),
            ("#8b949e", ""),
            ("#e6edf3", "you  ▸ /open report.md"),
            ("#58a6ff", "→ MdReader companion window"),
        ],
    )
    f2 = frame_viewer()
    # hold each frame ~1.6s
    f1.save(
        OUT,
        save_all=True,
        append_images=[f2],
        duration=[1600, 2200],
        loop=0,
        optimize=True,
    )
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
