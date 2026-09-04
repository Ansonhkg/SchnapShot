"""Render the 10s SchnapShot promo from original screenshots. Requires Pillow + ffmpeg.

Run: python3 promo/render.py
The sign-in screenshot is deliberately excluded because it contains a device code.
"""
from pathlib import Path
import math
import subprocess
import wave
from array import array
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output"
OUT.mkdir(exist_ok=True)
W, H, FPS = 1920, 1080, 30
BG = (17, 19, 24)
WHITE = (247, 245, 240)
MUTED = (169, 173, 182)
ORANGE = (255, 91, 54)
FONT = Path("/System/Library/Fonts/Supplemental")

def font(size, bold=False):
    return ImageFont.truetype(str(FONT / ("Arial Bold.ttf" if bold else "Arial.ttf")), size)

fonts = {(size, bold): font(size, bold) for size in [22, 26, 28, 30, 32, 36, 40, 48, 68, 82, 92, 112, 136] for bold in [False, True]}
result = Image.open(ROOT / "assets/result.png").convert("RGBA")
presets = Image.open(ROOT / "assets/presets.png").convert("RGBA")
# Video framing: isolate the supplied preset popover, leaving the source image untouched.
pw, ph = presets.size
presets = presets.crop((int(pw * .485), int(ph * .099), int(pw * .999), int(ph * .576)))
icon = Image.open(ROOT / "assets/app-icon.png").convert("RGBA")

def ease(x):
    x = max(0, min(1, x))
    return 1 - (1-x)**3

def text(im, xy, value, size=32, bold=False, color=WHITE):
    ImageDraw.Draw(im).text(xy, value, font=fonts[size, bold], fill=color, spacing=12)

def badge(im, xy, value):
    d = ImageDraw.Draw(im)
    f = fonts[26, True]
    width = d.textlength(value, font=f) + 40
    x, y = xy
    d.rounded_rectangle((x, y, x+width, y+48), radius=24, fill=(49, 32, 29))
    d.text((x+20, y+8), value, font=f, fill=ORANGE)

def picture(im, source, xy, width, radius=20):
    x,y = map(int, xy)
    h = round(width * source.height/source.width)
    img = source.resize((round(width), h), Image.Resampling.LANCZOS)
    mask = Image.new("L", img.size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width-1, h-1), radius=radius, fill=255)
    # Compose on a soft shadow, preserving source geometry and screenshot content.
    shadow = Image.new("RGBA", (img.width+100, h+100))
    ImageDraw.Draw(shadow).rounded_rectangle((40,40,img.width+60,h+60), radius=radius+4, fill=(0,0,0,120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))
    im.alpha_composite(shadow, (x-50,y-28))
    if source is icon:
        im.alpha_composite(img, (x,y))
    else:
        img.putalpha(mask)
        im.alpha_composite(img, (x,y))
    return h

def base(index):
    im = Image.new("RGBA", (W,H), BG+(255,))
    d = ImageDraw.Draw(im)
    d.line((84,1020,1836,1020), fill=(48,50,57), width=2)
    text(im,(84,1040),"LOCAL MAC APP  /  CODEX-POWERED IMAGE GENERATION",22,color=MUTED)
    text(im,(1730,1040),f"0{index+1} / 04",22,color=MUTED)
    return im

def scene(index, u):
    im = base(index)
    enter = ease(u/.5)
    shift = round((1-enter)*34)
    if index == 0:
        picture(im, icon, (76,72), 84)
        text(im,(174,94),"SchnapShot",36,True)
        badge(im,(96,264+shift),"FROM SCREENSHOT TO THUMBNAIL")
        text(im,(92,346+shift),"Your screenshot.\nSite-ready.",82,True)
        text(im,(96,603+shift),"A local app for your Mac.",36,color=MUTED)
        picture(im,result,(828+shift,212),1040+round(10*u))
    elif index == 1:
        badge(im,(96,120),"PICK YOUR PRESET")
        text(im,(92,261+shift),"1200 × 630",112,True,color=ORANGE)
        text(im,(96,426+shift),"The size your site needs.",48,True)
        text(im,(96,549+shift),"Tinkerer blog thumbnails.\nWebsite Open Graph images.",36,color=MUTED)
        text(im,(96,742),"Save the prompt. Reuse the preset.",30,color=MUTED)
        picture(im,presets,(958+shift,242),886)
    elif index == 2:
        badge(im,(96,120),"POWERED BY YOUR ACCOUNT")
        text(im,(92,273+shift),"Your Codex.\nYour image gen.",82,True)
        text(im,(96,529+shift),"Generate. Copy. Publish.",40,color=ORANGE)
        text(im,(96,647),"Made for blog posts\nand social previews.",36,color=MUTED)
        picture(im,result,(880+shift,144),954)
        badge(im,(1224,885),"COPIED TO CLIPBOARD")
        text(im,(96,947),"Generation uses OpenAI via your Codex account. Sequence condensed.",22,color=MUTED)
    else:
        picture(im,icon,(807,101+shift),306)
        d=ImageDraw.Draw(im)
        title="SchnapShot"
        tw=d.textlength(title,font=fonts[136,True])
        text(im,((W-tw)/2,430+shift),title,136,True)
        line="Capture. Generate. Copy."
        tw=d.textlength(line,font=fonts[48,True])
        text(im,((W-tw)/2,625+shift),line,48,True,color=ORANGE)
        line="Local Mac app. Your Codex account."
        tw=d.textlength(line,font=fonts[36,False])
        text(im,((W-tw)/2,728+shift),line,36,color=MUTED)
        text(im,(699,903),"BLOG THUMBNAILS  /  OPEN GRAPH",26,color=MUTED)
    return im

cuts=[0,2.2,5.0,7.8,10.0]
def frame(t):
    index=next(i for i in range(4) if t<cuts[i+1])
    im=scene(index,t-cuts[index])
    if index>0 and t-cuts[index]<.2:
        im=Image.blend(scene(index-1,cuts[index]-cuts[index-1]),im,ease((t-cuts[index])/.2))
    # Continuous orange progress line: motion without obscuring the real UI.
    ImageDraw.Draw(im).rectangle((84,1017,84+int(1752*t/10),1021),fill=ORANGE)
    return im.convert("RGB")

def soundtrack():
    rate=48000
    samples=array("h")
    for n in range(10*rate):
        t=n/rate
        s=0.0
        for start in cuts[:-1]:
            dt=t-start
            if 0<=dt<.24:
                s+=.13*math.sin(2*math.pi*(180*dt-150*dt*dt))*math.exp(-dt*24)*min(1,dt/.006)
        dt=t-7.8
        if dt>=0:
            envelope=min(1,dt/.03)*math.exp(-dt*2.0)*min(1,(10-t)/.3)
            s+=sum(math.sin(2*math.pi*f*dt) for f in [523.25,659.25,783.99])*.025*envelope
        samples.append(round(max(-1,min(1,s))*32767))
    with wave.open(str(OUT/"soundtrack.wav"),"wb") as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(samples.tobytes())

if __name__ == "__main__":
    soundtrack()
    command=["ffmpeg","-y","-hide_banner","-loglevel","error","-f","rawvideo","-pix_fmt","rgb24","-s",f"{W}x{H}","-r",str(FPS),"-i","-","-i",str(OUT/"soundtrack.wav"),"-c:v","libx264","-preset","medium","-crf","18","-pix_fmt","yuv420p","-c:a","aac","-b:a","160k","-t","10","-movflags","+faststart",str(OUT/"SchnapShot-promo-10s.mp4")]
    process=subprocess.Popen(command,stdin=subprocess.PIPE)
    for n in range(FPS*10):
        im=frame(n/FPS)
        process.stdin.write(im.tobytes())
        if n in [30,100,190,270]: im.save(OUT/f"review-{n:03}.png")
        if n%60==0: print(f"Rendered {n}/{FPS*10} frames",flush=True)
    process.stdin.close()
    if process.wait()!=0: raise SystemExit("Video encoding failed")
    frame(1).save(OUT/"poster.png")
    print(OUT/"SchnapShot-promo-10s.mp4")
