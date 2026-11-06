"""Reel title and end cards (docs/demo-video.md 5.1, the reel's graphics).

Rendered from the repository's own app icon and Windows' Segoe UI, so the reel
invents no logo. Run with the work folder's Pillow environment:

  $WORK/venv/Scripts/python.exe -I tools/demo/reel/graphics.py --work $WORK

Writes `title.png`, `end.png` (1920x1080) and the fade clips `title_fade.mp4`
and `end_fade.mp4` into `$WORK/graphics/`. The fade clips are 2 s, 60 fps,
H.264, from and to black, so the assembler can drop them in as title and end
cards without a filter graph.
"""

import argparse
import os
import subprocess

from PIL import Image, ImageDraw, ImageFont

W, H = 1920, 1080
BG = (18, 22, 28)
WHITE = (255, 255, 255)
GREY = (170, 178, 189)
DIM = (122, 130, 140)

SEMIBOLD = r"C:\Windows\Fonts\seguisb.ttf"
REGULAR = r"C:\Windows\Fonts\segoeui.ttf"

DISCLOSURE = "Recorded from the real apps. Every player is a script."
TAGLINE = "Your phone is the controller."
CREDIT = "Built by Manveer Wasson."
LINKS = [
    "devtestman187.github.io/game-controller",
    "github.com/devtestman187/game-controller",
]
STORES = "Google Play  \u00b7  TestFlight  \u00b7  Windows"
AUDIO_NOTE = "Music and join/countdown sounds: upcoming Thumb Party audio"


def font(path, size):
    return ImageFont.truetype(path, size)


def centred(draw, text, f, y, fill):
    left, top, right, bottom = draw.textbbox((0, 0), text, font=f)
    draw.text(((W - (right - left)) / 2 - left, y), text, font=f, fill=fill)
    return bottom - top


def card(icon, logo_px, name_y, name_px, tagline, extra, out):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    logo = Image.open(icon).convert("RGBA").resize((logo_px, logo_px), Image.LANCZOS)
    # The icon's own dark-blue square is its background; round it off so it sits
    # on the card's darker background as a logo, not as a screenshot.
    mask = Image.new("L", (logo_px, logo_px), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, logo_px - 1, logo_px - 1), radius=int(logo_px * 0.22), fill=255
    )
    img.paste(logo, ((W - logo_px) // 2, name_y - logo_px - 48), mask)
    centred(d, "Thumb Party", font(SEMIBOLD, name_px), name_y, WHITE)
    if tagline:
        centred(d, TAGLINE, font(REGULAR, 44), name_y + name_px + 26, GREY)
    for text, f, y, fill in extra:
        centred(d, text, f, y, fill)
    img.save(out, "PNG")
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=r"E:\AI\game-controller")
    ap.add_argument("--work", default=os.environ.get("WORK", ""))
    args = ap.parse_args()
    if not args.work:
        raise SystemExit("set WORK or pass --work (the runbook never guesses it)")
    out = os.path.join(args.work, "graphics")
    os.makedirs(out, exist_ok=True)
    icon = os.path.join(args.repo, "assets", "branding", "icon-app-1024.png")

    title = card(
        icon,
        logo_px=300,
        name_y=520,
        name_px=104,
        tagline=True,
        extra=[(DISCLOSURE, font(REGULAR, 30), 940, DIM)],
        out=os.path.join(out, "title.png"),
    )
    end = card(
        icon,
        logo_px=190,
        name_y=330,
        name_px=72,
        tagline=False,
        extra=[
            (LINKS[0], font(REGULAR, 38), 470, WHITE),
            (LINKS[1], font(REGULAR, 38), 522, WHITE),
            (STORES, font(REGULAR, 32), 600, GREY),
            (CREDIT, font(REGULAR, 30), 830, GREY),
            (AUDIO_NOTE, font(REGULAR, 30), 960, DIM),
            (DISCLOSURE, font(REGULAR, 26), 1010, DIM),
        ],
        out=os.path.join(out, "end.png"),
    )
    if not os.path.exists(os.path.join(out, "end.png")):
        raise SystemExit("the end card was not written")

    # Short fade clips: 2 s at 60 fps, from black / to black. Encoded here so the
    # assembler only has to copy them.
    for name, kind in (("title_fade", "in"), ("end_fade", "out")):
        src = os.path.join(out, "title.png" if kind == "in" else "end.png")
        dst = os.path.join(out, name + ".mp4")
        fade = "fade=t=in:st=0:d=0.6" if kind == "in" else "fade=t=out:st=1.4:d=0.6"
        subprocess.run(
            [
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-loop", "1", "-i", src,
                "-vf", f"{fade},format=yuv420p",
                "-t", "2", "-r", "60", "-c:v", "libx264", "-crf", "18",
                "-pix_fmt", "yuv420p", dst,
            ],
            check=True,
        )
    print(f"graphics: {out}")


if __name__ == "__main__":
    main()
