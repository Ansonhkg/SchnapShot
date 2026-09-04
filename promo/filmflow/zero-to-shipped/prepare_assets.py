"""Normalize supplied screenshots into crisp 1920×1080 Filmflow keyframes."""
from pathlib import Path
from PIL import Image, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "assets/source"
SIZE = (1920, 1080)

def cover(image, size):
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))

def framed(source, output, foreground_height=1010):
    image = Image.open(source).convert("RGB")
    background = cover(image, SIZE).filter(ImageFilter.GaussianBlur(42))
    background = ImageEnhance.Brightness(background).enhance(0.34)
    scale = min(1820 / image.width, foreground_height / image.height)
    foreground = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    x = (SIZE[0] - foreground.width) // 2
    y = (SIZE[1] - foreground.height) // 2
    background.paste(foreground, (x, y))
    background.save(output, quality=95)

framed(SOURCE / "default-thumbnail.png", ROOT / "assets/default-frame.png")
website = cover(Image.open(SOURCE / "website.png").convert("RGB"), SIZE)
website.save(ROOT / "assets/website-frame.png", quality=95)
framed(SOURCE / "schnapshot-result.png", ROOT / "assets/result-frame.png")
