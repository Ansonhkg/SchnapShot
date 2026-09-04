"""Edit the approved story into an exact 10-second 1080p master."""
from pathlib import Path
import subprocess
import cv2
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
DEFAULT = ROOT / "assets/default-frame.png"
WEBSITE = ROOT / "video/shots/01-website/video.mp4"
RESULT = ROOT / "video/shots/02-result/video.mp4"
ENDING = ROOT / "assets/ending-frame.png"
SOUND = ROOT / "assets/soundtrack.wav"
BASE = ROOT / "video/base-transition-edit.mp4"
OUTPUT = ROOT / "video/SchnapShot-zero-to-shipped-10s.mp4"
FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 52)
W, H, FPS = 1920, 1080, 30
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

# 2.35 + 3.05 + 3.00 + 2.20 - (3 × .20) = 10 seconds.
base_filter = (
    "[0:v]scale=1920:1080,setsar=1,fps=30,trim=duration=2.35,setpts=PTS-STARTPTS[v0];"
    "[1:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,"
    "fps=30,trim=duration=3.05,setpts=PTS-STARTPTS[v1];"
    "[2:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,"
    "fps=30,trim=duration=3.00,setpts=PTS-STARTPTS[v2];"
    "[3:v]scale=1920:1080,setsar=1,fps=30,trim=duration=2.20,setpts=PTS-STARTPTS[v3];"
    "[v0][v1]xfade=transition=fadeblack:duration=0.20:offset=2.15[x1];"
    "[x1][v2]xfade=transition=fadeblack:duration=0.20:offset=5.00[x2];"
    "[x2][v3]xfade=transition=fadeblack:duration=0.20:offset=7.80,format=yuv420p[v]"
)

subprocess.run([
    "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
    "-loop", "1", "-framerate", "30", "-t", "2.35", "-i", str(DEFAULT),
    "-i", str(WEBSITE), "-i", str(RESULT),
    "-loop", "1", "-framerate", "30", "-t", "2.20", "-i", str(ENDING),
    "-filter_complex", base_filter, "-map", "[v]", "-an",
    "-c:v", "libx264", "-preset", "medium", "-crf", "12", "-t", "10", str(BASE),
], check=True)

captions = [
    (0.25, 2.05, "This thumbnail doesn't sell it."),
    (2.40, 4.25, "The website does."),
    (4.30, 4.95, "Capture what works."),
    (5.25, 7.65, "1200 × 630. Ready."),
]

encoder = subprocess.Popen([
    "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
    "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
    "-i", str(SOUND), "-c:v", "libx264", "-preset", "medium", "-crf", "18",
    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
    "-t", "10", "-movflags", "+faststart", str(OUTPUT),
], stdin=subprocess.PIPE)

capture = cv2.VideoCapture(str(BASE))
for frame_number in range(FPS * 10):
    ok, bgr = capture.read()
    if not ok:
        raise RuntimeError(f"Base edit ended early at frame {frame_number}")
    frame = Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(frame, "RGBA")
    t = frame_number / FPS
    for start, end, copy in captions:
        if start <= t <= end:
            draw.rounded_rectangle((56, 850, 1036, 962), radius=14, fill=(8, 9, 12, 208))
            draw.text((88, 879), copy, font=FONT, fill=(247, 245, 240, 255))
            break
    if 4.30 <= t <= 4.95:
        draw.rectangle((105, 105, 1815, 885), outline=(255, 91, 54, 244), width=5)
    encoder.stdin.write(frame.tobytes())

capture.release()
encoder.stdin.close()
if encoder.wait() != 0:
    raise SystemExit("Final encode failed")
print(OUTPUT)
