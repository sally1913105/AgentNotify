#!/usr/bin/env python3
"""Generate the AgentNotify macOS application icon at all required sizes."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "resources" / "AppIcon.icns"
MASTER_SIZE = 1024


def draw_master() -> Image.Image:
    image = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))

    tile = (88, 88, 936, 936)
    draw = ImageDraw.Draw(image)
    # A single graphite squircle follows the macOS icon silhouette.
    draw.rounded_rectangle(tile, radius=205, fill=(34, 43, 58, 255))

    # Message bubble with a bold checkmark: clear at both Finder and small sizes.
    bubble = (220, 240, 804, 700)
    draw.rounded_rectangle(bubble, radius=120, fill=(240, 93, 94, 255))
    draw.polygon([(330, 655), (255, 790), (462, 684)], fill=(240, 93, 94, 255))
    draw.line((342, 468, 472, 588, 685, 354), fill=(255, 255, 255, 255), width=58, joint="curve")
    # Rounded line caps keep the checkmark friendly rather than geometric.
    for x, y in ((342, 468), (685, 354)):
        draw.ellipse((x - 29, y - 29, x + 29, y + 29), fill=(255, 255, 255, 255))
    return image


def main() -> None:
    master = draw_master()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    master.save(OUTPUT, format="ICNS", sizes=[(16, 16), (32, 32), (64, 64),
                                                     (128, 128), (256, 256),
                                                     (512, 512), (1024, 1024)])
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
