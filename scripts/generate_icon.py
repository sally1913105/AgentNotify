#!/usr/bin/env python3
"""Generate the AgentNotify macOS application icon at all required sizes."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "resources" / "AppIcon.icns"
MASTER_SIZE = 1024


def draw_master() -> Image.Image:
    image = Image.new("RGBA", (MASTER_SIZE, MASTER_SIZE), (0, 0, 0, 0))

    # A restrained navy/teal tile keeps the icon legible in both light and dark Finder themes.
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    tile = (104, 104, 920, 920)
    shadow_draw.rounded_rectangle((tile[0], tile[1] + 22, tile[2], tile[3] + 22), radius=190, fill=(0, 0, 0, 95))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))

    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(tile, radius=190, fill=(24, 61, 86, 255))
    draw.rounded_rectangle((tile[0] + 10, tile[1] + 10, tile[2] - 10, tile[3] - 10), radius=180, outline=(78, 157, 157, 180), width=8)

    # Notification bell: clapper, body, and a clean open base.
    bell = (304, 274, 720, 718)
    draw.ellipse((421, 688, 603, 798), fill=(245, 250, 248, 255))
    draw.rectangle((399, 684, 625, 728), fill=(24, 61, 86, 255))
    draw.pieslice((bell[0], bell[1], bell[2], bell[3] + 170), 180, 360, fill=(245, 250, 248, 255))
    draw.rectangle((bell[0], 495, bell[2], 690), fill=(245, 250, 248, 255))
    draw.ellipse((bell[0], 620, bell[2], bell[3] + 170), fill=(245, 250, 248, 255))
    draw.rectangle((bell[0] - 18, 654, bell[2] + 18, 714), fill=(245, 250, 248, 255))
    draw.ellipse((481, 216, 543, 278), fill=(245, 250, 248, 255))

    # Warm unread indicator, echoing the menu bar badge.
    draw.ellipse((657, 236, 806, 385), fill=(248, 178, 74, 255), outline=(255, 226, 164, 255), width=7)
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
