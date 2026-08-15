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


def screenshot_svg(width: int, height: int, title: str, subtitle: str, mode: str, accent: str) -> str:
    landscape = width > height
    board_w = int(width * (0.56 if landscape else 0.78))
    board_h = int(height * (0.56 if landscape else 0.38))
    board_x = int(width * (0.38 if landscape else 0.11))
    board_y = int(height * (0.20 if landscape else 0.38))
    hud_x = int(width * 0.07)
    hud_y = int(height * 0.16)
    title_size = int(width * (0.052 if landscape else 0.074))
    subtitle_size = int(width * (0.024 if landscape else 0.037))
    card_w = int(width * (0.24 if landscape else 0.78))
    card_h = int(height * (0.13 if landscape else 0.08))
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0a1022"/>
      <stop offset=".48" stop-color="#18213d"/>
      <stop offset="1" stop-color="#101013"/>
    </linearGradient>
    <linearGradient id="arena" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#26365f"/>
      <stop offset="1" stop-color="#11172c"/>
    </linearGradient>
  </defs>
  <rect width="{width}" height="{height}" fill="#11182f"/>
  <rect x="0" y="0" width="{width}" height="{int(height*.18)}" fill="#1c294d"/>
  <circle cx="{int(width*.83)}" cy="{int(height*.14)}" r="{int(width*.16)}" fill="{accent}" opacity=".24"/>
  <rect x="{hud_x}" y="{hud_y - int(title_size*.7)}" width="{int(width*.36)}" height="{int(title_size*.9)}" rx="{int(title_size*.2)}" fill="#f8f2de" opacity="1"/>
  <rect x="{hud_x}" y="{hud_y + int(title_size*.45)}" width="{int(width*.46)}" height="{int(subtitle_size*.7)}" rx="{int(subtitle_size*.2)}" fill="#9da8c8" opacity="1"/>
  <rect x="{hud_x}" y="{hud_y + int(title_size*2.0)}" width="{card_w}" height="{card_h}" rx="28" fill="#202942" opacity="1"/>
  <rect x="{hud_x + 36}" y="{hud_y + int(title_size*2.0) + int(card_h*.24)}" width="{int(card_w*.34)}" height="{int(card_h*.14)}" rx="8" fill="#ffffff" opacity=".55"/>
  <rect x="{hud_x + 36}" y="{hud_y + int(title_size*2.0) + int(card_h*.55)}" width="{int(card_w*.62)}" height="{int(card_h*.18)}" rx="8" fill="{accent}" opacity=".92"/>
  <rect x="{board_x}" y="{board_y}" width="{board_w}" height="{board_h}" rx="42" fill="#1d2d55" stroke="#f8f2de" stroke-width="6" opacity="1"/>
  <g opacity=".18" stroke="#ffffff" stroke-width="3">
    <path d="M{board_x+60} {board_y+int(board_h*.33)} H{board_x+board_w-60}"/>
    <path d="M{board_x+60} {board_y+int(board_h*.66)} H{board_x+board_w-60}"/>
    <path d="M{board_x+int(board_w*.33)} {board_y+60} V{board_y+board_h-60}"/>
    <path d="M{board_x+int(board_w*.66)} {board_y+60} V{board_y+board_h-60}"/>
  </g>
  <circle cx="{board_x+int(board_w*.25)}" cy="{board_y+int(board_h*.32)}" r="{int(width*.035)}" fill="#60e27a" stroke="#f7ffe8" stroke-width="8"/>
  <circle cx="{board_x+int(board_w*.74)}" cy="{board_y+int(board_h*.34)}" r="{int(width*.035)}" fill="#ff7048" stroke="#fff0e8" stroke-width="8"/>
  <circle cx="{board_x+int(board_w*.36)}" cy="{board_y+int(board_h*.72)}" r="{int(width*.035)}" fill="#51d7ff" stroke="#e8fbff" stroke-width="8"/>
  <circle cx="{board_x+int(board_w*.62)}" cy="{board_y+int(board_h*.68)}" r="{int(width*.035)}" fill="#ffd43b" stroke="#fff8d0" stroke-width="8"/>
  <path d="M{board_x+int(board_w*.18)} {board_y+int(board_h*.5)} C{board_x+int(board_w*.38)} {board_y+int(board_h*.22)} {board_x+int(board_w*.63)} {board_y+int(board_h*.78)} {board_x+int(board_w*.82)} {board_y+int(board_h*.46)}" fill="none" stroke="{accent}" stroke-width="18" stroke-linecap="round" opacity=".78"/>
  <rect x="{int(width*.08)}" y="{int(height*.83)}" width="{int(width*.84)}" height="{int(height*.08)}" rx="32" fill="#202942" opacity="1"/>
  <rect x="{int(width*.12)}" y="{int(height*.858)}" width="{int(width*.18)}" height="{int(height*.018)}" rx="10" fill="#f8f2de" opacity="1"/>
  <rect x="{int(width*.39)}" y="{int(height*.858)}" width="{int(width*.40)}" height="{int(height*.014)}" rx="10" fill="#9da8c8" opacity="1"/>
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
        ("iphone-01-party-arena.png", 2778, 1284, "Party Arena", "Four players. One fast challenge.", "Mini-game rush", "#ffb347"),
        ("iphone-02-fast-rounds.png", 2778, 1284, "Fast Rounds", "Jump in, score, and pass the lead.", "Score chase", "#51d7ff"),
        ("iphone-03-local-chaos.png", 2778, 1284, "Local Chaos", "Designed for quick competitive sessions.", "Couch play", "#60e27a"),
        ("ipad-01-party-arena.png", 2732, 2048, "Party Arena", "Built for big-screen iPad play.", "Mini-game rush", "#ffb347"),
        ("ipad-02-fast-rounds.png", 2732, 2048, "Fast Rounds", "Clear goals, readable HUD, quick restarts.", "Score chase", "#51d7ff"),
        ("ipad-03-local-chaos.png", 2732, 2048, "Local Chaos", "Multiple modes for repeatable party sessions.", "Couch play", "#60e27a"),
    ]
    for filename, width, height, title, subtitle, mode, accent in shots:
        svg_path = SOURCE_DIR / f"{filename}.svg"
        write(svg_path, screenshot_svg(width, height, title, subtitle, mode, accent))
        run_magick(svg_path, SHOT_DIR / filename, (width, height))


if __name__ == "__main__":
    main()
