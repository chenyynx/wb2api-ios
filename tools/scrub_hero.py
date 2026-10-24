#!/usr/bin/env python3
"""把拼接展示图里的敏感账号信息打码（账号昵称 / 邮箱 / 掩码手机号）。"""
import json
import re
import subprocess
import sys

from PIL import Image, ImageDraw

PATTERNS = [
    re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    re.compile(r"\d{2,4}\*{2,}\d{0,4}"),
    re.compile(r"jinbung\w*", re.I),
    re.compile(r"chenyyn\w*|chenyunx\w*", re.I),
    re.compile(r"@|gmail|qq\.com|163\.com", re.I),
]


def ocr(path):
    out = subprocess.run(
        ["apple-vision", "ocr", "--lang", "zh-Hans,en", "--level", "accurate", path],
        capture_output=True, text=True, check=True).stdout
    return json.loads(out)["data"]["blocks"]


def redact(img, blocks):
    im = img.convert("RGB").copy()
    w, h = im.size
    hits = 0
    for b in blocks:
        text = b.get("text", "")
        if not any(p.search(text) for p in PATTERNS):
            continue
        x, y, bw, bh = b["bbox"]
        box = [max(0, int(x * w) - 14), max(0, int((1 - y - bh) * h) - 10),
               min(w, int((x + bw) * w) + 14), min(h, int((1 - y) * h) + 10)]
        crop = im.crop(box)
        bwid, bhei = crop.size
        small = crop.resize((max(2, bwid // 14), max(2, bhei // 14)), Image.BILINEAR)
        im.paste(small.resize((bwid, bhei), Image.NEAREST), box)
        hits += 1
        print(f"  打码: {text[:40]!r}")
    return im, hits


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/hero-src.jpg"
    dst = sys.argv[2] if len(sys.argv) > 2 else "docs/screenshots/hero.png"
    img = Image.open(src)
    blocks = ocr(src)
    print(f"OCR {len(blocks)} 块")
    out, n = redact(img, blocks)
    out.save(dst, "PNG", optimize=True)
    print(f"完成 {dst}，打码 {n} 处，尺寸 {out.size}")


if __name__ == "__main__":
    main()
