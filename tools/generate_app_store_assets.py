#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "app_store"
ICON_DIR = ASSET_DIR / "icons"
SHOT_DIR = ASSET_DIR / "screenshots"
SOURCE_DIR = ASSET_DIR / "source"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def run_magick(source: Path, target: Path, size: tuple[int, int]) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "magick",
            "-font",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "-background",
            "none",
            str(source),
            "-resize",
            f"{size[0]}x{size[1]}!",
            "-alpha",
            "remove",
            "-alpha",
            "off",
            str(target),
        ],
        check=True,
    )


def icon_svg() -> str:
    return """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="48%" cy="35%" r="74%">
      <stop offset="0" stop-color="#39446e"/>
      <stop offset="0.58" stop-color="#161b33"/>
      <stop offset="1" stop-color="#070a14"/>
    </radialGradient>
    <linearGradient id="ring" x1="120" y1="116" x2="902" y2="908">
      <stop offset="0" stop-color="#ffe08a"/>
      <stop offset="0.45" stop-color="#ff9d45"/>
      <stop offset="1" stop-color="#5be7a9"/>
    </linearGradient>
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="18" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  <rect width="1024" height="1024" fill="#101832"/>
  <rect x="34" y="34" width="956" height="956" rx="190" fill="#17234a"/>
  <circle cx="804" cy="190" r="220" fill="#273a78" opacity=".8"/>
  <circle cx="512" cy="512" r="344" fill="none" stroke="#fff4c4" stroke-width="18" opacity=".22"/>
  <path d="M512 154c186 0 337 151 337 337 0 102-45 194-117 256" fill="none" stroke="url(#ring)" stroke-width="54" stroke-linecap="round" filter="url(#glow)"/>
  <path d="M514 870c-186 0-337-151-337-337 0-102 45-194 117-256" fill="none" stroke="#51d7ff" stroke-width="54" stroke-linecap="round" opacity=".88" filter="url(#glow)"/>
  <path d="M332 516c34-84 117-144 214-144 79 0 149 39 191 99" fill="none" stroke="#ffffff" stroke-width="24" stroke-linecap="round" opacity=".28"/>
  <circle cx="512" cy="512" r="128" fill="#0b1024" stroke="#ffe08a" stroke-width="20"/>
  <path d="M512 405l42 76 85 17-59 65 10 87-78-36-78 36 10-87-59-65 85-17z" fill="#ffe08a"/>
  <circle cx="512" cy="146" r="58" fill="#60e27a" stroke="#f7ffe8" stroke-width="12"/>
  <circle cx="878" cy="512" r="58" fill="#ff7048" stroke="#fff0e8" stroke-width="12"/>
  <circle cx="512" cy="878" r="58" fill="#51d7ff" stroke="#e8fbff" stroke-width="12"/>
  <circle cx="146" cy="512" r="58" fill="#ffd43b" stroke="#fff8d0" stroke-width="12"/>
  <rect x="334" y="744" width="356" height="66" rx="33" fill="#ffffff" opacity=".22"/>
  <circle cx="404" cy="777" r="18" fill="#60e27a"/>
  <circle cx="476" cy="777" r="18" fill="#ff7048"/>
  <circle cx="548" cy="777" r="18" fill="#51d7ff"/>
  <circle cx="620" cy="777" r="18" fill="#ffd43b"/>
</svg>
"""


def screenshot_svg(width: int, height: int, screen: str, accent: str) -> str:
    """Render App Store screenshots as in-app UI, not marketing posters.

    The current project builds its UI procedurally in Godot. These SVGs mirror
    the app's shipped colors, HUD structure, player chips, menus and result
    screens so the product page shows the actual app concept in use.
    """
    landscape = width > height
    margin = int(width * 0.045)
    top_h = int(height * 0.12)
    bottom_h = int(height * 0.14)
    title_size = int(width * (0.032 if landscape else 0.044))
    body_size = int(width * (0.019 if landscape else 0.026))
    small_size = int(width * (0.014 if landscape else 0.020))
    arena_x = int(width * (0.34 if landscape else 0.10))
    arena_y = int(height * (0.20 if landscape else 0.33))
    arena_w = int(width * (0.58 if landscape else 0.80))
    arena_h = int(height * (0.56 if landscape else 0.42))
    side_x = margin
    side_y = int(height * 0.18)
    side_w = int(width * (0.25 if landscape else 0.82))
    chip_y = int(height * 0.82)
    chip_w = int((width - margin * 2 - 48) / 4)

    def text(x: int, y: int, value: str, size: int, fill: str = "#f2f4ff", weight: int = 600, anchor: str = "start") -> str:
        return f'<text x="{x}" y="{y}" font-family="Arial" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}">{value}</text>'

    def pill(x: int, y: int, w: int, h: int, fill: str, stroke: str = "", opacity: str = "1") -> str:
        stroke_part = f' stroke="{stroke}" stroke-width="4"' if stroke else ""
        return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{int(h * 0.24)}" fill="{fill}" opacity="{opacity}"{stroke_part}/>'

    player_colors = ["#60e27a", "#ff7048", "#51d7ff", "#ffd43b"]
    player_names = ["Nabta", "Sakhra", "Mowja", "Barq"]

    arena = f"""
  <rect x="{arena_x}" y="{arena_y}" width="{arena_w}" height="{arena_h}" rx="36" fill="#17264a" stroke="#f8f2de" stroke-width="6"/>
  <g opacity=".18" stroke="#ffffff" stroke-width="3">
    <path d="M{arena_x+50} {arena_y+int(arena_h*.33)} H{arena_x+arena_w-50}"/>
    <path d="M{arena_x+50} {arena_y+int(arena_h*.66)} H{arena_x+arena_w-50}"/>
    <path d="M{arena_x+int(arena_w*.33)} {arena_y+50} V{arena_y+arena_h-50}"/>
    <path d="M{arena_x+int(arena_w*.66)} {arena_y+50} V{arena_y+arena_h-50}"/>
  </g>
  <path d="M{arena_x+int(arena_w*.15)} {arena_y+int(arena_h*.52)} C{arena_x+int(arena_w*.37)} {arena_y+int(arena_h*.18)} {arena_x+int(arena_w*.64)} {arena_y+int(arena_h*.83)} {arena_x+int(arena_w*.84)} {arena_y+int(arena_h*.42)}" fill="none" stroke="{accent}" stroke-width="18" stroke-linecap="round" opacity=".75"/>
  <circle cx="{arena_x+int(arena_w*.25)}" cy="{arena_y+int(arena_h*.31)}" r="{int(width*.032)}" fill="#60e27a" stroke="#eaffef" stroke-width="8"/>
  <circle cx="{arena_x+int(arena_w*.74)}" cy="{arena_y+int(arena_h*.34)}" r="{int(width*.032)}" fill="#ff7048" stroke="#fff0e8" stroke-width="8"/>
  <circle cx="{arena_x+int(arena_w*.39)}" cy="{arena_y+int(arena_h*.72)}" r="{int(width*.032)}" fill="#51d7ff" stroke="#e8fbff" stroke-width="8"/>
  <circle cx="{arena_x+int(arena_w*.62)}" cy="{arena_y+int(arena_h*.68)}" r="{int(width*.032)}" fill="#ffd43b" stroke="#fff8d0" stroke-width="8"/>
  <circle cx="{arena_x+int(arena_w*.50)}" cy="{arena_y+int(arena_h*.50)}" r="{int(width*.018)}" fill="#ffffff" opacity=".9"/>
"""

    chips = []
    for i, (name, color) in enumerate(zip(player_names, player_colors)):
        x = margin + i * (chip_w + 16)
        chips.append(pill(x, chip_y, chip_w, int(height * 0.095), "#1a1f3a", color, ".96"))
        chips.append(f'<circle cx="{x+34}" cy="{chip_y+34}" r="13" fill="{color}"/>')
        chips.append(text(x + 58, chip_y + 39, name, small_size, "#f2f4ff", 700))
        chips.append(text(x + 58, chip_y + 78, str([12, 8, 10, 6][i]), body_size, color, 800))

    if screen == "gameplay":
        side = f"""
  {pill(side_x, side_y, side_w, int(height*.42), "#1a1f3a", "", ".95")}
  {text(side_x+34, side_y+60, "Ring Rumble", title_size, "#ffb347", 800)}
  {text(side_x+34, side_y+112, "Push rivals out of the arena", body_size, "#f2f4ff", 600)}
  {text(side_x+34, side_y+165, "Round 2 of 4", body_size, "#9aa2c8", 500)}
  {pill(side_x+34, side_y+205, int(side_w*.70), 42, "#252c52")}
  {text(side_x+58, side_y+235, "Power-ups ON", small_size, "#57e0c0", 700)}
  {pill(side_x+34, side_y+270, int(side_w*.78), 42, "#252c52")}
  {text(side_x+58, side_y+300, "Touch controls visible", small_size, "#f2f4ff", 700)}
  <circle cx="{int(width*.50)}" cy="{int(height*.10)}" r="{int(height*.058)}" fill="#1a1f3a" stroke="#ffb347" stroke-width="5"/>
  {text(int(width*.50), int(height*.115), "0:42", title_size, "#f2f4ff", 800, "middle")}
"""
        controls = f"""
  <circle cx="{int(width*.12)}" cy="{int(height*.70)}" r="{int(width*.045)}" fill="#252c52" stroke="#9aa2c8" stroke-width="4" opacity=".92"/>
  <circle cx="{int(width*.85)}" cy="{int(height*.68)}" r="{int(width*.036)}" fill="#252c52" stroke="#ffb347" stroke-width="4" opacity=".92"/>
  <circle cx="{int(width*.91)}" cy="{int(height*.75)}" r="{int(width*.036)}" fill="#252c52" stroke="#57e0c0" stroke-width="4" opacity=".92"/>
"""
        body = side + arena + controls + "\n".join(chips)
    elif screen == "tournament":
        left_w = int(width * 0.44)
        row_h = int(height * 0.085)
        rows = []
        labels = [("Players", "4"), ("Preset", "Chaos Cup"), ("Rounds", "6"), ("Difficulty", "Hard")]
        for i, (label, value) in enumerate(labels):
            y = int(height * 0.25) + i * int(row_h * 1.15)
            rows.append(pill(margin, y, left_w, row_h, "#1a1f3a", "", ".96"))
            rows.append(text(margin + 34, y + int(row_h*.58), label, body_size, "#9aa2c8", 600))
            rows.append(text(margin + left_w - 34, y + int(row_h*.58), value, body_size, "#f2f4ff", 800, "end"))
        card_x = int(width * 0.55)
        card_y = int(height * 0.24)
        body = f"""
  {text(margin, int(height*.16), "Tournament Setup", title_size, "#ffb347", 800)}
  {''.join(rows)}
  {pill(margin, int(height*.72), left_w, int(height*.10), "#ffb347")}
  {text(margin + int(left_w*.5), int(height*.785), "Start Cup", body_size, "#101321", 800, "middle")}
  {pill(card_x, card_y, int(width*.34), int(height*.46), "#1a1f3a", "#57e0c0", ".96")}
  <circle cx="{card_x+int(width*.17)}" cy="{card_y+int(height*.17)}" r="{int(width*.060)}" fill="#60e27a" stroke="#eaffef" stroke-width="8"/>
  {text(card_x+int(width*.17), card_y+int(height*.32), "Nabta", title_size, "#f2f4ff", 800, "middle")}
  {text(card_x+int(width*.17), card_y+int(height*.38), "Speed 85  Jump 70  Control 90", small_size, "#9aa2c8", 600, "middle")}
  {pill(card_x+50, card_y+int(height*.40), int(width*.28), 34, "#252c52")}
  {text(card_x+int(width*.17), card_y+int(height*.423), "Unlocked character selected", small_size, "#57e0c0", 700, "middle")}
"""
    else:
        row_w = int(width * 0.78)
        start_y = int(height * 0.26)
        rows = []
        standings = [("1", "Nabta", "18", "#60e27a"), ("2", "Mowja", "14", "#51d7ff"), ("3", "Sakhra", "11", "#ff7048"), ("4", "Barq", "8", "#ffd43b")]
        for i, (rank, name, score, color) in enumerate(standings):
            y = start_y + i * int(height * 0.105)
            rows.append(pill(int(width*.11), y, row_w, int(height*.075), "#1a1f3a", color, ".96"))
            rows.append(text(int(width*.14), y + int(height*.050), rank, body_size, color, 800))
            rows.append(text(int(width*.22), y + int(height*.050), name, body_size, "#f2f4ff", 800))
            rows.append(text(int(width*.84), y + int(height*.050), score + " pts", body_size, "#f2f4ff", 800, "end"))
        body = f"""
  {text(int(width*.50), int(height*.17), "Cup Results", title_size, "#ffb347", 800, "middle")}
  {text(int(width*.50), int(height*.225), "Gem Grab - Ring Rumble - Quick Draw", body_size, "#9aa2c8", 600, "middle")}
  {''.join(rows)}
  {pill(int(width*.20), int(height*.74), int(width*.26), int(height*.08), "#252c52", "#57e0c0", ".96")}
  {text(int(width*.33), int(height*.792), "Replay Match", body_size, "#f2f4ff", 800, "middle")}
  {pill(int(width*.54), int(height*.74), int(width*.26), int(height*.08), "#ffb347", "", "1")}
  {text(int(width*.67), int(height*.792), "Next Round", body_size, "#101321", 800, "middle")}
"""

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0a1022"/>
      <stop offset=".48" stop-color="#18213d"/>
      <stop offset="1" stop-color="#101013"/>
    </linearGradient>
  </defs>
  <rect width="{width}" height="{height}" fill="url(#bg)"/>
  <rect x="0" y="0" width="{width}" height="{top_h}" fill="#0d1020"/>
  <rect x="0" y="{height-bottom_h}" width="{width}" height="{bottom_h}" fill="#0d1020" opacity=".78"/>
  <text x="{margin}" y="{int(top_h*.64)}" font-family="Arial" font-size="{body_size}" font-weight="800" fill="#ffb347">Kras Pass</text>
  <text x="{width-margin}" y="{int(top_h*.64)}" font-family="Arial" font-size="{small_size}" font-weight="700" fill="#9aa2c8" text-anchor="end">Arabic / English - Local Party Game</text>
{body}
</svg>
"""


def main() -> None:
    source_icon = SOURCE_DIR / "kras-pass-icon.svg"
    write(source_icon, icon_svg())

    icon_sizes = {
        "Icon-40.png": (40, 40),
        "Icon-58.png": (58, 58),
        "Icon-60.png": (60, 60),
        "Icon-76.png": (76, 76),
        "Icon-80.png": (80, 80),
        "Icon-87.png": (87, 87),
        "Icon-114.png": (114, 114),
        "Icon-120.png": (120, 120),
        "Icon-128.png": (128, 128),
        "Icon-136.png": (136, 136),
        "Icon-152.png": (152, 152),
        "Icon-167.png": (167, 167),
        "Icon-180.png": (180, 180),
        "Icon-192.png": (192, 192),
        "Icon-1024.png": (1024, 1024),
    }
    for name, size in icon_sizes.items():
        run_magick(source_icon, ICON_DIR / name, size)

    shots = [
        ("iphone-01-party-arena.png", 2778, 1284, "gameplay", "#ffb347"),
        ("iphone-02-fast-rounds.png", 2778, 1284, "tournament", "#51d7ff"),
        ("iphone-03-local-chaos.png", 2778, 1284, "results", "#60e27a"),
        ("ipad-01-party-arena.png", 2732, 2048, "gameplay", "#ffb347"),
        ("ipad-02-fast-rounds.png", 2732, 2048, "tournament", "#51d7ff"),
        ("ipad-03-local-chaos.png", 2732, 2048, "results", "#60e27a"),
    ]
    for filename, width, height, screen, accent in shots:
        svg_path = SOURCE_DIR / f"{filename}.svg"
        write(svg_path, screenshot_svg(width, height, screen, accent))
        run_magick(svg_path, SHOT_DIR / filename, (width, height))


if __name__ == "__main__":
    main()
