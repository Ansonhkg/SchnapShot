"""Native 1080p screenshot choreography, rendered through Filmflow's local hook.

No generated UI: references, cursor, camera, selection and replacement are composited
at output resolution. The interaction is a condensed demonstration, not a recording.
"""
from pathlib import Path
import math
import subprocess
import wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / 'assets'
OUT = ROOT / 'video'
W, H, FPS = 1920, 1080, 30
BG = (15, 17, 22)
ORANGE = (255, 91, 40)
WHITE = (248, 246, 242)
FONTDIR = Path('/System/Library/Fonts/Supplemental')

def font(size, bold=False):
    return ImageFont.truetype(str(FONTDIR / ('Arial Bold.ttf' if bold else 'Arial.ttf')), size)

FONTS = {s: font(s, True) for s in (22, 26, 30, 40, 48, 56, 116)}

def clamp(x):
    return max(0., min(1., x))

def ease(x):
    x = clamp(x)
    return x*x*(3-2*x)

def lerp(a, b, u):
    return a + (b-a)*u

def mixrect(a, b, u):
    return tuple(lerp(x,y,u) for x,y in zip(a,b))

def paste(im, src, rect, radius=18):
    x,y,w,h = [round(v) for v in rect]
    if w < 1 or h < 1:
        return
    tile = src.resize((w,h), Image.Resampling.LANCZOS).convert('RGBA')
    mask = Image.new('L', (w,h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1), radius=radius, fill=255)
    tile.putalpha(mask)
    im.paste(tile, (x,y), tile)

sources = {k: Image.open(ASSETS / (k+'.png')).convert('RGB') for k in ('listing','website','result')}
logo_src = Image.open(ASSETS / 'approved-logo.png').convert('RGB')
# Trim only the black presentation margin. The supplied icon artwork stays intact.
bright = np.asarray(logo_src).max(axis=2) > 100
ys,xs = np.where(bright)
logo = logo_src.crop((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))

def fit(src):
    s = min(1770/src.width, 850/src.height)
    w,h = src.width*s, src.height*s
    return ((W-w)/2, 115+(850-h)/2,w,h)

rects = {k: fit(v) for k,v in sources.items()}
backgrounds = {}
for k,src in sources.items():
    im = Image.new('RGB',(W,H),BG)
    paste(im,src,rects[k])
    backgrounds[k]=im

def relative(k, box):
    x,y,w,h = rects[k]
    a,b,c,d = box
    return (x+a*w,y+b*h,(c-a)*w,(d-b)*h)

CARD = relative('listing',(.4458,.2242,.9820,.6105))
INNER = relative('result',(.042,.1885,.957,.846))
SELECTION = relative('website',(.015,.347,.982,.945))
rr = rects['result']
COPY = (rr[0]+rr[2]*.94,rr[1]+rr[3]*.96)
sw,sh = sources['result'].size
thumbnail = sources['result'].crop((int(sw*.042),int(sh*.1885),int(sw*.957),int(sh*.846)))

def camera(im, zoom=1., focus=(960,540)):
    cx,cy=focus
    return im.transform((W,H),Image.Transform.AFFINE,
        (1/zoom,0,cx-W/(2*zoom),0,1/zoom,cy-H/(2*zoom)),
        resample=Image.Resampling.BICUBIC,fillcolor=BG)

def mapped(p, zoom, focus):
    return ((p[0]-focus[0])*zoom+W/2,(p[1]-focus[1])*zoom+H/2)

def mapbox(box, zoom, focus):
    x,y=mapped(box[:2],zoom,focus)
    return (x,y,box[2]*zoom,box[3]*zoom)

def cursor(im, p, click_age=None, cross=False):
    x,y=p
    d=ImageDraw.Draw(im,'RGBA')
    if click_age is not None and 0 <= click_age < .32:
        u=click_age/.32
        r=12+45*u
        d.ellipse((x-r,y-r,x+r,y+r),outline=(*ORANGE,round(255*(1-u))),width=4)
        d.ellipse((x-12,y-12,x+12,y+12),fill=(*ORANGE,round(110*(1-u))))
    if cross:
        for col,width in [((0,0,0,220),7),((255,255,255,255),3)]:
            d.line((x-17,y,x+17,y),fill=col,width=width)
            d.line((x,y-17,x,y+17),fill=col,width=width)
        return
    s=.87 if click_age is not None and 0<=click_age<.10 else 1.
    points=[(0,0),(0,40),(10,30),(19,48),(27,44),(18,26),(33,26)]
    pts=[(x+a*s,y+b*s) for a,b in points]
    d.polygon([(a+2,b+3) for a,b in pts],fill=(0,0,0,120))
    d.polygon(pts,fill=(255,255,255,255))
    d.line(pts+[pts[0]],fill=(12,15,20,255),width=3)

def corners(im, rect, col=ORANGE):
    x,y,w,h=rect
    d=ImageDraw.Draw(im)
    n=min(30,w/4,h/4)
    for a,b,sx,sy in [(x,y,1,1),(x+w,y,-1,1),(x,y+h,1,-1),(x+w,y+h,-1,-1)]:
        d.line((a+sx*n,b,a,b,a,b+sy*n),fill=col,width=6)

def chip(im, value, pos, color=WHITE):
    d=ImageDraw.Draw(im)
    x,y=pos
    width=d.textlength(value,font=FONTS[26])+36
    d.rounded_rectangle((x,y,x+width,y+47),radius=10,fill=(29,32,40),outline=(66,68,75),width=1)
    d.text((x+18,y+9),value,font=FONTS[26],fill=color)

def chrome(im,t,caption):
    d=ImageDraw.Draw(im)
    d.rectangle((0,0,W,100),fill=BG)
    d.rectangle((0,985,W,H),fill=BG)
    if caption:
        d.text((76,27),caption,font=FONTS[48],fill=WHITE)
    d.text((76,1014),'Workflow demo · Generation time condensed',font=FONTS[22],fill=(150,153,163))
    d.text((1674,1014),'SchnapShot',font=FONTS[22],fill=WHITE)
    d.line((76,1060,1844,1060),fill=(45,47,54),width=3)
    d.line((76,1060,76+1768*t/10,1060),fill=ORANGE,width=3)

def listing_camera(t):
    u=ease((t-.55)/.95)
    c=(CARD[0]+CARD[2]*.5,CARD[1]+CARD[3]*.52)
    return lerp(1,1.45,u),(lerp(960,c[0]-170,u),lerp(540,c[1]+60,u))

def listing(t):
    z,f=listing_camera(t)
    im=camera(backgrounds['listing'],z,f)
    bx=mapbox(CARD,z,f)
    target=(bx[0]+bx[2]*.54,bx[1]+bx[3]*.52)
    if t>1.25:
        d=ImageDraw.Draw(im)
        x,y,w,h=bx
        d.rounded_rectangle((x-3,y-3,x+w+3,y+h+3),radius=20,outline=ORANGE,width=4)
    u=ease((t-.7)/.82)
    p=(lerp(420,target[0],u),lerp(890,target[1],u))
    cursor(im,p,t-1.75)
    chrome(im,t,"This thumbnail doesn't sell it.")
    return im

def website(t, decorate=True):
    u=ease((t-2.4)/.85)
    z=lerp(1,1.04,u)
    focus=(960,lerp(540,568,u))
    im=camera(backgrounds['website'],z,focus)
    sel=mapbox(SELECTION,z,focus)
    x,y,w,h=sel
    if t<3.3:
        q=ease((t-2.4)/.9)
        cursor(im,(lerp(1120,x,q),lerp(620,y,q)))
    else:
        q=ease((t-3.4)/.85)
        ex,ey=x+max(3,w*q),y+max(3,h*q)
        shade=Image.new('RGBA',(W,H),(0,0,0,90))
        sd=ImageDraw.Draw(shade)
        sd.rectangle((x,y,ex,ey),fill=(0,0,0,0))
        im=Image.alpha_composite(im.convert('RGBA'),shade).convert('RGB')
        d=ImageDraw.Draw(im)
        d.rectangle((x,y,ex,ey),outline=ORANGE,width=2)
        corners(im,(x,y,ex-x,ey-y))
        cursor(im,(ex,ey),cross=True)
        chip(im, f'{round((ex-x))} × {round((ey-y))}',(min(ex-190,1670),min(ey+12,913)),ORANGE)
    if decorate:
        chrome(im,t,'Capture what works.' if t>=3.3 else 'The website does.')
    return im

def app(t):
    im=backgrounds['result'].copy()
    x,y,w,h=INNER
    progress=ease((t-5.04)/1.10)
    if t<6.22:
        # Hide the finished reference while generation progresses, then reveal it.
        d=ImageDraw.Draw(im)
        edge=x+w*progress
        d.rectangle((edge,y,x+w,y+h),fill=(25,28,35))
        d.line((edge,y,edge,y+h),fill=ORANGE,width=4)
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((x,y+h+7,x+w,y+h+18),radius=5,fill=(44,47,55))
    if progress>0:
        d.rounded_rectangle((x,y+h+7,x+w*progress,y+h+18),radius=5,fill=ORANGE)
    # Explicitly show progress and copy state, covering the source's old status.
    d.rectangle((rr[0]+rr[2]*.145,rr[1]+rr[3]*.93,rr[0]+rr[2]*.72,rr[1]+rr[3]*.989),fill=(24,28,33))
    d.text((rr[0]+rr[2]*.16,rr[1]+rr[3]*.944),
        'Copied to clipboard' if t>=6.72 else ('Thumbnail ready' if t>=6.22 else 'Rendering with Codex…'),
        font=FONTS[22],fill=(99,226,159) if t>=6.22 else WHITE)
    z=lerp(1,1.055,ease((t-6.05)/.5))
    f=(960,550)
    im=camera(im,z,f)
    pcopy=mapped(COPY,z,f)
    if t>=6.22:
        u=ease((t-6.22)/.43)
        p=(lerp(1090,pcopy[0],u),lerp(630,pcopy[1],u))
        if t>=6.57:
            chip(im,'Copied!' if t>=6.72 else 'Copy',(pcopy[0]-85,pcopy[1]-94),(99,226,159) if t>=6.72 else WHITE)
        cursor(im,p,t-6.72)
    chrome(im,t,'1200 × 630. Ready.' if t>=6.22 else 'SchnapShot is rendering…')
    return im

def replacement(t):
    base=backgrounds['listing'].copy()
    x,y,w,h=CARD
    target=base.copy()
    paste(target,thumbnail,CARD,radius=15)
    u=ease((t-7.55)/.43)
    if u>0:
        # Update only the existing card artwork: surrounding page remains stable.
        edge=round(x+w*u)
        base.paste(target.crop((round(x),round(y),edge,round(y+h))),(round(x),round(y)))
        if u<1:
            ImageDraw.Draw(base).line((edge,y,edge,y+h),fill=ORANGE,width=5)
    z=lerp(1.05,1.47,ease((t-7.28)/.8))
    c=(x+w*.5-160,y+h*.52+75)
    f=(lerp(960,c[0],ease((t-7.28)/.8)),lerp(540,c[1],ease((t-7.28)/.8)))
    im=camera(base,z,f)
    targetp=mapped((x+w*.6,y+h*.48),z,f)
    cursor(im,targetp,t-7.53)
    if t>7.96:
        b=mapbox(CARD,z,f)
        chip(im,'✓ Thumbnail updated',(b[0]+b[2]-340,b[1]-62),(99,226,159))
    chrome(im,t,'Much better.' if t>7.85 else 'Back to Tinkerer. Replace.')
    return im

def ending(t):
    im=Image.new('RGB',(W,H),BG)
    shift=round(20*(1-ease((t-8.62)/.35)))
    paste(im,logo,(807,112+shift,306,306),radius=67)
    d=ImageDraw.Draw(im)
    for copy,y,size,col in [('SchnapShot',461,116,WHITE),('Capture. Generate. Copy.',651,48,ORANGE),('Local Mac app. Your Codex account.',750,30,(169,173,182))]:
        width=d.textlength(copy,font=FONTS[size])
        d.text(((W-width)/2,y+shift),copy,font=FONTS[size],fill=col)
    d.text((700,941),'BLOG THUMBNAILS  /  OPEN GRAPH',font=FONTS[26],fill=(169,173,182))
    d.line((76,1032,1844,1032),fill=ORANGE,width=3)
    return im

def frame(t):
    if t<2.10:
        return listing(t)
    if t<2.40:
        im=listing(2.09)
        z,f=listing_camera(2.09)
        origin=mapbox(CARD,z,f)
        u=ease((t-2.10)/.30)
        paste(im,website(2.40, decorate=False),mixrect(origin,(0,0,W,H),u))
        chrome(im,t,'The website does.')
        return im
    if t<4.50:
        return website(t)
    if t<5.0:
        u=ease((t-4.50)/.50)
        im=Image.blend(website(4.49),app(5.0),ease((t-4.50)/.22))
        # Fly just the selected pixels into the editor, never the promo chrome.
        origin=mapbox(SELECTION,1.04,(960,568))
        raw=camera(backgrounds['website'],1.04,(960,568))
        x,y,w,h=origin
        captured=raw.crop((round(x),round(y),round(x+w),round(y+h)))
        target=mapbox(INNER,1.,(960,550))
        tx,ty,tw,th=target
        scale=min(tw/captured.width,th/captured.height)
        cw,ch=captured.width*scale,captured.height*scale
        target=(tx+(tw-cw)/2,ty+(th-ch)/2,cw,ch)
        tile=im.copy()
        paste(tile,captured,mixrect(origin,target,u),radius=4)
        im=Image.blend(tile,im,ease((t-4.85)/.15))
        chrome(im,t,'SchnapShot is rendering…')
        flash=max(0,1-abs(t-4.63)/.09)
        return Image.blend(im,Image.new('RGB',(W,H),(255,210,150)),flash*.70)
    if t<7.1:
        return app(t)
    if t<7.36:
        u=ease((t-7.1)/.26)
        im=Image.new('RGB',(W,H),BG)
        im.paste(app(7.09),(round(-W*u),0))
        im.paste(replacement(7.36),(round(W*(1-u)),0))
        return im
    if t<8.48:
        return replacement(t)
    if t<8.65:
        return Image.blend(replacement(8.47),Image.new('RGB',(W,H),BG),ease((t-8.48)/.17))
    im=ending(t)
    return Image.blend(Image.new('RGB',(W,H),BG),im,ease((t-8.65)/.18))

def sound():
    rate=48000
    timeline=np.arange(rate*10)/rate
    samples=np.zeros(rate*10)
    # Short interface clicks and directional whooshes timed to visible actions.
    for start in (0.05,1.75,3.4,4.50,6.72,7.53,7.98):
        dt=timeline-start
        env=np.exp(-np.maximum(dt,0)*42)*((dt>=0)&(dt<.18))
        samples+=.13*np.sin(2*np.pi*(700*dt-850*dt*dt))*env*np.minimum(np.maximum(dt,0)/.003,1)
    rng=np.random.default_rng(16)
    noise=rng.normal(0,1,len(samples))
    smooth=np.convolve(noise,np.ones(17)/17,mode='same')
    for start,length in ((2.1,.3),(4.5,.35),(7.1,.26)):
        u=np.clip((timeline-start)/length,0,1)
        samples+=.09*smooth*np.sin(np.pi*u)**2
    # Reuse the first promo's actual resolving chord for the requested ending.
    with wave.open(str(ASSETS/'original-soundtrack.wav'),'rb') as wf:
        original=np.frombuffer(wf.readframes(wf.getnframes()),dtype='<i2').astype(float)/32768
        assert wf.getframerate()==rate
    chord=original[round(7.8*rate):]
    start=round(8.66*rate)
    count=min(len(chord),len(samples)-start)
    samples[start:start+count]+=chord[:count]
    samples*=np.clip((10-timeline)/.12,0,1)
    with wave.open(str(OUT/'soundtrack.wav'),'wb') as wf:
        wf.setnchannels(1);wf.setsampwidth(2);wf.setframerate(rate)
        wf.writeframes((np.clip(samples,-.95,.95)*32767).astype('<i2').tobytes())

def main():
    OUT.mkdir(exist_ok=True)
    sound()
    output=OUT/'SchnapShot-interactive-1080p.mp4'
    command=['ffmpeg','-y','-hide_banner','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','30','-i','-','-i',str(OUT/'soundtrack.wav'),'-c:v','libx264','-preset','medium','-crf','17','-pix_fmt','yuv420p','-c:a','aac','-b:a','192k','-t','10','-movflags','+faststart',str(output)]
    encoder=subprocess.Popen(command,stdin=subprocess.PIPE)
    try:
        for n in range(300):
            im=frame(n/FPS)
            encoder.stdin.write(im.tobytes())
            if n in (25,54,83,118,146,170,204,239,284):
                im.save(OUT/f'review-{n:03}.png')
            if n%60==0:
                print(f'Rendered {n}/300 frames',flush=True)
    finally:
        encoder.stdin.close()
    if encoder.wait()!=0:
        raise RuntimeError('Video encoding failed')
    print(output)

if __name__=='__main__':
    main()
