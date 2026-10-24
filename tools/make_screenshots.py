"""把 App 截图做脱敏 + 套手机外框，产出 README 用的展示图。

用法：python3 tools/make_screenshots.py
输入：/var/minis/attachments/uploads/*.png（5 张）
输出：docs/screenshots/*.png
"""
import json
import os
import re
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter

SRC = [
    ("01-overview", "/var/minis/attachments/uploads/photo_A2E4542B.png"),
    ("02-accounts", "/var/minis/attachments/uploads/photo_A0A62F27.png"),
    ("03-tasks", "/var/minis/attachments/uploads/photo_625A6A13.png"),
    ("04-data", "/var/minis/attachments/uploads/photo_B5E83443.png"),
    ("05-more", "/var/minis/attachments/uploads/photo_C437D890.png"),
]

OUT_DIR = "docs/screenshots"

SENSITIVE = [
    re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    re.compile(r"\d{2,4}\*{2,}\d{0,4}"),
    re.compile(r"jinbung\w*"),
    re.compile(r"chenyyn\w*"),
    # OCR 会把邮箱切成多段：任何含 @ / gmail / qq.com 的块都要盖
    re.compile(r"@|gmail|qq\.com|163\.com", re.I),
]

BEZEL = 26
RADIUS = 116


def ocr(path: str) -> list:
    out = subprocess.run(
        ["apple-vision", "ocr", "--lang", "zh-Hans,en", "--level", "accurate", path],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(out)["data"]["blocks"]


def redact(img: Image.Image, blocks: list) -> Image.Image:
    img = img.copy()
    w, h = img.size
    for block in blocks:
        text = block.get("text", "")
        if not any(p.search(text) for p in SENSITIVE):
            continue
        x, y, bw, bh = block["bbox"]
        # Vision 的 bbox 原点在左下
        left = int(x * w) - 14
        right = int((x + bw) * w) + 14
        top = int((1 - y - bh) * h) - 10
        bottom = int((1 - y) * h) + 10
        left, top = max(0, left), max(0, top)
        right, bottom = min(w, right), min(h, bottom)
        if right - left < 4 or bottom - top < 4:
            continue
        crop = img.crop((left, top, right, bottom))
        # 马赛克：缩小再放大
        small = crop.resize((max(2, (right - left) // 14), max(2, (bottom - top) // 14)), Image.BILINEAR)
        mosaic = small.resize((right - left, bottom - top), Image.NEAREST)
        img.paste(mosaic, (left, top))
    return img


def frame(img: Image.Image) -> Image.Image:
    """套一层手机外框（黑边 + 灵动岛），带柔和投影，透明底。"""
    target_w = 780
    ratio = target_w / img.width
    shot = img.resize((target_w, int(img.height * ratio)), Image.LANCZOS)
    w, h = shot.size

    pad = BEZEL + 18
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2 + 24), (0, 0, 0, 0))

    # 投影
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        [pad - 6, pad + 16, pad + w + 6, pad + h + 22],
        radius=RADIUS, fill=(20, 16, 40, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas = Image.alpha_composite(canvas, shadow)

    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(
        [pad - BEZEL, pad - BEZEL, pad + w + BEZEL, pad + h + BEZEL],
        radius=RADIUS + BEZEL, fill=(16, 16, 18, 255),
    )
    d.rounded_rectangle(
        [pad - 6, pad - 6, pad + w + 6, pad + h + 6],
        radius=RADIUS + 6, outline=(58, 58, 66, 255), width=3,
    )

    # 圆角裁切屏幕
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=RADIUS, fill=255)
    canvas.paste(shot, (pad, pad), mask)

    # 灵动岛
    island_w, island_h = int(w * 0.30), 34
    ix = pad + (w - island_w) // 2
    d.rounded_rectangle([ix, pad + 14, ix + island_w, pad + 14 + island_h],
                        radius=island_h // 2, fill=(0, 0, 0, 255))
    return canvas


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, path in SRC:
        if not os.path.exists(path):
            print("skip missing", path)
            continue
        img = Image.open(path).convert("RGB")
        blocks = ocr(path)
        clean = redact(img, blocks)
        framed = frame(clean)
        out = os.path.join(OUT_DIR, f"{name}.png")
        framed.save(out, "PNG", optimize=True)
        print("written", out, framed.size)


if __name__ == "__main__":
    main()
