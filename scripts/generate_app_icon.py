"""Generate square TrackIT TI launcher icon (1024px)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "images" / "app_icon.png"
SIZE = 1024
RED = "#C62828"
WHITE = "#FFFFFF"
BLACK = "#000000"


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path(r"C:\Windows\Fonts\arialbd.ttf"),
        Path(r"C:\Windows\Fonts\ARIALBD.TTF"),
        Path(r"C:\Windows\Fonts\segoeuib.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def main() -> None:
    img = Image.new("RGB", (SIZE, SIZE), BLACK)
    draw = ImageDraw.Draw(img)

    cx = cy = SIZE // 2
    radius = 360
    stroke = 34

    bbox = [cx - radius, cy - radius, cx + radius, cy + radius]
    draw.arc(bbox, start=30, end=300, fill=RED, width=stroke)
    draw.arc(bbox, start=300, end=390, fill=WHITE, width=stroke)

    font = load_font(300)
    text = "TI"
    t_bbox = draw.textbbox((0, 0), text, font=font)
    tw = t_bbox[2] - t_bbox[0]
    th = t_bbox[3] - t_bbox[1]
    x = cx - tw // 2 - 8
    y = cy - th // 2 - 24

    draw.text((x, y), "T", font=font, fill=WHITE)
    t_w = draw.textbbox((0, 0), "T", font=font)[2]
    draw.text((x + t_w - 18, y), "I", font=font, fill=RED)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG", optimize=True)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
