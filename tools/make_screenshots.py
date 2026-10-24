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
    """套一层接近实机的 iPhone 外框：窄边、金属描边、侧键、灵动岛、双层投影。"""
    target_w = 720
    ratio = target_w / img.width
    shot = img.resize((target_w, int(img.height * ratio)), Image.LANCZOS)
    w, h = shot.size

    bezel = 11                 # 窄边框
    screen_radius = 92
    frame_radius = screen_radius + bezel
    margin = 54

    canvas = Image.new("RGBA", (w + bezel * 2 + margin * 2, h + bezel * 2 + margin * 2), (0, 0, 0, 0))
    ox, oy = margin, margin
    fx0, fy0 = ox, oy
    fx1, fy1 = ox + w + bezel * 2, oy + h + bezel * 2

    # 远投影 + 近投影
    for blur, alpha, dy in ((34, 55, 22), (10, 45, 6)):
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.rounded_rectangle([fx0 + 2, fy0 + dy + 2, fx1 - 2, fy1 + dy], radius=frame_radius, fill=(18, 14, 40, alpha))
        canvas = Image.alpha_composite(canvas, layer.filter(ImageFilter.GaussianBlur(blur)))

    d = ImageDraw.Draw(canvas)

    # 侧键（细窄，压在机身下）
    btn = (74, 74, 78, 255)
    d.rounded_rectangle([fx0 - 5, fy0 + 132, fx0, fy0 + 176], radius=3, fill=btn)
    d.rounded_rectangle([fx0 - 5, fy0 + 208, fx0, fy0 + 292], radius=3, fill=btn)
    d.rounded_rectangle([fx0 - 5, fy0 + 312, fx0, fy0 + 396], radius=3, fill=btn)
    d.rounded_rectangle([fx1, fy0 + 232, fx1 + 5, fy0 + 336], radius=3, fill=btn)

    # 金属中框（外圈渐变感：两层描边）
    d.rounded_rectangle([fx0, fy0, fx1, fy1], radius=frame_radius, fill=(28, 28, 30, 255))
    d.rounded_rectangle([fx0, fy0, fx1, fy1], radius=frame_radius, outline=(126, 126, 134, 255), width=2)
    d.rounded_rectangle([fx0 + 2, fy0 + 2, fx1 - 2, fy1 - 2], radius=frame_radius - 2, outline=(58, 58, 62, 255), width=2)
    d.rounded_rectangle([fx0 + bezel - 1, fy0 + bezel - 1, fx1 - bezel + 1, fy1 - bezel + 1],
                        radius=screen_radius + 1, fill=(0, 0, 0, 255))

    # 屏幕
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w, h], radius=screen_radius, fill=255)
    canvas.paste(shot, (fx0 + bezel, fy0 + bezel), mask)

    # 灵动岛 + 摄像头
    island_w, island_h = int(w * 0.255), 26
    ix = fx0 + bezel + (w - island_w) // 2
    iy = fy0 + bezel + 11
    d.rounded_rectangle([ix, iy, ix + island_w, iy + island_h], radius=island_h // 2, fill=(0, 0, 0, 255))
    d.ellipse([ix + island_w - 22, iy + 7, ix + island_w - 11, iy + 18], fill=(26, 26, 30, 255))
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
