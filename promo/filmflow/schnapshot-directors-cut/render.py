"""Assemble the steadier Filmflow revision into an exact 10-second master."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
INTRO = ROOT / "video/shots/03-steady-intro/video.mp4"
PRESET = ROOT / "assets/shot-01-end.png"
CODEX = ROOT / "video/shots/04-steady-codex/video.mp4"
CLOSE = ROOT / "assets/shot-02-end.png"
SOUND = ROOT / "assets/soundtrack.wav"
OUTPUT = ROOT / "video/SchnapShot-directors-cut-v3-10s.mp4"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

# Four readable beats joined by short, deterministic editorial dissolves.
# 3.15 + 2.15 + 3.15 + 2.15 - (3 × .20) = 10.00 seconds.
video_filter = (
    "[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,"
    "setsar=1,fps=30,trim=duration=3.15,setpts=PTS-STARTPTS[v0];"
    "[1:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,"
    "setsar=1,fps=30,trim=duration=2.15,setpts=PTS-STARTPTS[v1];"
    "[2:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,"
    "setsar=1,fps=30,trim=duration=3.15,setpts=PTS-STARTPTS[v2];"
    "[3:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,"
    "setsar=1,fps=30,trim=duration=2.15,setpts=PTS-STARTPTS[v3];"
    "[v0][v1]xfade=transition=fadeblack:duration=0.20:offset=2.95[x1];"
    "[x1][v2]xfade=transition=fadeblack:duration=0.20:offset=4.90[x2];"
    "[x2][v3]xfade=transition=fadeblack:duration=0.20:offset=7.85,format=yuv420p[v]"
)

command = [
    "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
    "-i", str(INTRO),
    "-loop", "1", "-framerate", "30", "-t", "2.15", "-i", str(PRESET),
    "-i", str(CODEX),
    "-loop", "1", "-framerate", "30", "-t", "2.15", "-i", str(CLOSE),
    "-i", str(SOUND),
    "-filter_complex", video_filter, "-map", "[v]", "-map", "4:a:0",
    "-c:v", "libx264", "-preset", "medium", "-crf", "18",
    "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k",
    "-t", "10", "-movflags", "+faststart", str(OUTPUT),
]
subprocess.run(command, check=True)
print(OUTPUT)
