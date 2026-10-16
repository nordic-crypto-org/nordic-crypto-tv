#!/usr/bin/env python3
"""Frames App Store screenshots and draws the product-page header images.

Colours are Nordic Crypto's store palette: teal #1E3A45 and gold #D9A034.
The key-shield mark is assets/brand/key-shield.svg; this script draws the same
geometry because the Mac mini workflow does not depend on an SVG renderer.

Screenshots are composited onto a canvas of the exact pixel size Apple accepts
for that display. Header images have no alpha channel (Apple rejects it), no
prices, no web addresses and no copyright mark. The important part sits in the
centre: the product-page header is cropped at the sides and the top corners
carry the system buttons.

  python3 support/appstore/frame_media.py --raw build/appstore/raw --out build/appstore/framed --headers build/appstore/headers
"""
import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

from slots import CAPTIONS, HEADERS, SLOTS

TEAL = (0x1E, 0x3A, 0x45)
TEAL_RAISED = (0x2A, 0x4C, 0x59)
GOLD = (0xD9, 0xA0, 0x34)
CREAM = (0xF6, 0xF1, 0xE6)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def font(size, bold=False):
    names = (
        ["Georgia Bold.ttf", "Times New Roman Bold.ttf", "DejaVuSerif-Bold.ttf", "LiberationSerif-Bold.ttf"]
        if bold else
        ["Georgia.ttf", "Times New Roman.ttf", "DejaVuSerif.ttf", "DejaVuSans.ttf", "LiberationSans-Regular.ttf"]
    )
    roots = [
        "/System/Library/Fonts/Supplemental",
        "/Library/Fonts",
        "/usr/share/fonts/truetype/dejavu",
        "/usr/share/fonts/truetype/liberation",
        "/usr/share/fonts/truetype/liberation2",
    ]
    for root in roots:
        for name in names:
            path = os.path.join(root, name)
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def key_shield(size):
    """Teal heater shield with a gold key. Matches assets/brand/key-shield.svg."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size
    outline = max(2, s // 18)
    body = [(0.18 * s, 0.08 * s), (0.82 * s, 0.08 * s), (0.88 * s, 0.38 * s), (0.50 * s, 0.94 * s), (0.12 * s, 0.38 * s)]
    draw.polygon(body, fill=TEAL + (255,))
    draw.line(body + [body[0]], fill=GOLD + (255,), width=outline)
    cx, cy, r = 0.50 * s, 0.34 * s, 0.09 * s
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=GOLD + (255,), width=outline)
    draw.line([(cx, cy + r), (cx, 0.74 * s)], fill=GOLD + (255,), width=outline)
    draw.line([(cx, 0.62 * s), (0.64 * s, 0.62 * s)], fill=GOLD + (255,), width=outline)
    draw.line([(cx, 0.70 * s), (0.60 * s, 0.70 * s)], fill=GOLD + (255,), width=outline)
    return img


def _text(draw, xy, text, face, fill):
    draw.text(xy, text, font=face, fill=fill + (255,))


def _paste_rounded(canvas, shot, box, radius, border):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    if w < 4 or h < 4:
        return
    fitted = shot.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    canvas.paste(fitted, (x0, y0), mask)
    ImageDraw.Draw(canvas).rounded_rectangle([x0, y0, x1 - 1, y1 - 1], radius=radius, outline=GOLD + (255,), width=border)


def frame_screenshot(shot, size, caption):
    """Brand band on top, the app filling the rest, exact `size` pixels."""
    w, h = size
    canvas = Image.new("RGBA", size, TEAL + (255,))
    draw = ImageDraw.Draw(canvas)
    band = max(96, int(h * 0.112))
    draw.rectangle([0, band - 4, w, band], fill=GOLD + (255,))
    pad = int(min(w, h) * 0.035)
    mark = key_shield(int(band * 0.62))
    canvas.alpha_composite(mark, (pad, (band - mark.size[1]) // 2))
    text_x = pad + mark.size[0] + pad
    title = font(max(28, int(band * 0.28)), bold=True)
    sub = font(max(16, int(band * 0.16)))
    _text(draw, (text_x, int(band * 0.18)), "Nordic Crypto", title, CREAM)
    _text(draw, (text_x, int(band * 0.56)), caption, sub, GOLD)
    margin = int(min(w, h) * 0.028)
    radius = max(12, int(min(w, h) * 0.02))
    border = max(3, int(min(w, h) * 0.003))
    _paste_rounded(canvas, shot, (margin, band + margin, w - margin, h - margin), radius, border)
    return canvas


def _lockup(canvas, center, shield_size, subtitle):
    draw = ImageDraw.Draw(canvas)
    mark = key_shield(shield_size)
    x = center[0] - mark.size[0] // 2
    y = center[1] - int(shield_size * 1.15)
    canvas.alpha_composite(mark, (x, y))
    title = font(max(40, shield_size // 3), bold=True)
    sub = font(max(22, shield_size // 8))
    countries = font(max(18, shield_size // 11))
    tw = draw.textlength("Nordic Crypto", font=title)
    _text(draw, (center[0] - tw / 2, y + mark.size[1] + shield_size * 0.08), "Nordic Crypto", title, CREAM)
    rule = shield_size * 0.7
    ry = y + mark.size[1] + shield_size * 0.52
    draw.rectangle([center[0] - rule / 2, ry, center[0] + rule / 2, ry + max(4, shield_size // 40)], fill=GOLD + (255,))
    sw = draw.textlength(subtitle, font=sub)
    _text(draw, (center[0] - sw / 2, ry + shield_size * 0.12), subtitle, sub, GOLD)
    line = "Norway   ·   Sweden   ·   Denmark   ·   Finland   ·   Iceland"
    cw = draw.textlength(line, font=countries)
    _text(draw, (center[0] - cw / 2, ry + shield_size * 0.32), line, countries, CREAM)


def header_wide():
    """3840×1646 product-page header. Content stays inside the centre 70%."""
    size = HEADERS["product-page-header-3840x1646.png"]["size"]
    canvas = Image.new("RGBA", size, TEAL + (255,))
    draw = ImageDraw.Draw(canvas)
    w, h = size
    # A gold arc behind the mark, inset so the cropped sides and top corners stay empty.
    inset = int(w * 0.22)
    draw.arc([inset, int(h * 0.08), w - inset, int(h * 1.15)], start=200, end=340, fill=GOLD + (255,), width=6)
    _lockup(canvas, (w // 2, int(h * 0.46)), int(h * 0.28), "Crypto news from the Nordics")
    return canvas


def header_universal():
    """5244×2950 universal creative, the same picture for the header and search."""
    size = HEADERS["universal-5244x2950.png"]["size"]
    canvas = Image.new("RGBA", size, TEAL + (255,))
    draw = ImageDraw.Draw(canvas)
    w, h = size
    _lockup(canvas, (int(w * 0.32), int(h * 0.48)), int(h * 0.22), "Crypto news from the Nordics")
    # A calm list, not a screenshot of a headline, so the 4+ creative stays clear of the news copy.
    panel = [int(w * 0.56), int(h * 0.18), int(w * 0.86), int(h * 0.82)]
    draw.rounded_rectangle(panel, radius=36, fill=TEAL_RAISED + (255,), outline=GOLD + (255,), width=4)
    label = font(max(28, int(h * 0.035)), bold=True)
    row_font = font(max(22, int(h * 0.028)))
    _text(draw, (panel[0] + 48, panel[1] + 40), "Today", label, CREAM)
    draw.rectangle([panel[0] + 48, panel[1] + 110, panel[0] + 180, panel[1] + 118], fill=GOLD + (255,))
    rows = ["Norway", "Sweden", "Denmark", "Finland", "Iceland"]
    for i, name in enumerate(rows):
        y = panel[1] + 170 + i * int((panel[3] - panel[1] - 220) / len(rows))
        draw.rounded_rectangle([panel[0] + 48, y, panel[2] - 48, y + int(h * 0.07)], radius=16, fill=TEAL + (255,))
        draw.rectangle([panel[0] + 48, y, panel[0] + 60, y + int(h * 0.07)], fill=GOLD + (255,))
        _text(draw, (panel[0] + 88, y + int(h * 0.018)), name, row_font, CREAM)
    return canvas


def save_rgb(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rgb = Image.new("RGB", img.size, TEAL)
    rgb.paste(img.convert("RGBA"), mask=img.convert("RGBA").getchannel("A"))
    rgb.save(path, "PNG", optimize=True)
    return rgb


def screen_name(filename):
    stem = os.path.splitext(os.path.basename(filename))[0]
    parts = stem.split("-", 1)
    return parts[1] if len(parts) == 2 else stem


def generate(raw_dir, out_dir, headers_dir):
    written = []
    for device, slot in SLOTS.items():
        folder = os.path.join(raw_dir, device)
        if not os.path.isdir(folder):
            continue
        files = sorted(f for f in os.listdir(folder) if f.lower().endswith(".png"))
        for name in files:
            shot = Image.open(os.path.join(folder, name))
            caption = CAPTIONS.get(screen_name(name), "Nordic crypto news")
            framed = frame_screenshot(shot, slot["size"], caption)
            dest = os.path.join(out_dir, device, "en", name)
            save_rgb(framed, dest)
            written.append(dest)
    headers = {
        "product-page-header-3840x1646.png": header_wide(),
        "universal-5244x2950.png": header_universal(),
    }
    for name, img in headers.items():
        dest = os.path.join(headers_dir, name)
        save_rgb(img, dest)
        written.append(dest)
    return written


def verify(out_dir, headers_dir):
    """Exit with a message when a required file is missing or the wrong size."""
    problems = []
    for device, slot in SLOTS.items():
        folder = os.path.join(out_dir, device, "en")
        files = sorted(f for f in os.listdir(folder) if f.lower().endswith(".png")) if os.path.isdir(folder) else []
        if not files:
            problems.append(f"{device}: no framed screenshots")
            continue
        for name in files:
            with Image.open(os.path.join(folder, name)) as img:
                if img.size != slot["size"] or img.mode != "RGB":
                    problems.append(f"{device}/{name}: {img.mode} {img.size}, want RGB {slot['size']}")
    for name, spec in HEADERS.items():
        path = os.path.join(headers_dir, name)
        if not os.path.exists(path):
            problems.append(f"missing {name}")
            continue
        with Image.open(path) as img:
            if img.size != spec["size"] or img.mode != "RGB":
                problems.append(f"{name}: {img.mode} {img.size}, want RGB {spec['size']}")
            if img.getpixel((0, 0)) != TEAL or img.getpixel((img.size[0] - 1, img.size[1] - 1)) != TEAL:
                problems.append(f"{name}: background does not reach the corners")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--headers", required=True)
    ap.add_argument("--skip-verify", action="store_true",
                    help="still write what was captured; used when a simulator capture already failed")
    args = ap.parse_args()
    written = generate(args.raw, args.out, args.headers)
    problems = verify(args.out, args.headers)
    manifest = {
        "files": [os.path.relpath(p, ROOT) for p in written],
        "problems": problems,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(os.path.join(os.path.dirname(os.path.abspath(args.out)), "manifest.json"), "w") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")
    for p in written:
        print(p)
    if problems and not args.skip_verify:
        raise SystemExit("framed media failed checks:\n  " + "\n  ".join(problems))
    if problems:
        print("checks not enforced:\n  " + "\n  ".join(problems))


if __name__ == "__main__":
    main()
