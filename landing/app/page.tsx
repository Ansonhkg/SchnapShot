'use client';

import { useEffect, useState } from 'react';
import { ArrowDown, Check, Clipboard, Command, Monitor, Play, SlidersHorizontal, Sparkles } from 'lucide-react';

const paths = [
  { number: '01', label: 'Blog thumbnail', size: '1200 × 630', detail: 'Capture your draft. Pick Thumbnail. Upload a site-ready image to Tinkerer.' },
  { number: '02', label: 'Open Graph image', size: '1200 × 630', detail: 'Turn the page on your screen into a share image sized for your website metadata.' },
  { number: '03', label: 'App icon', size: '1024 × 1024', detail: 'Switch to the Icon preset and reuse the same capture with a completely different prompt.' },
];

function CaptureFlow() {
  const [showDirectorNote, setShowDirectorNote] = useState(false);
  useEffect(() => setShowDirectorNote(new URLSearchParams(window.location.search).get('dev') === 'true'), []);

  return (
    <div className="flow-visual" aria-label="A screenshot moving through Codex into a precisely sized image">
      <svg viewBox="0 0 960 250" role="img" aria-labelledby="flow-title flow-description">
        <title id="flow-title">Capture, generate, copy</title>
        <desc id="flow-description">A selected screen area becomes a 1200 by 630 image and is copied to the clipboard.</desc>
        <defs>
          <linearGradient id="orange" x1="0" x2="1"><stop offset="0" stopColor="#ff4f24" /><stop offset="1" stopColor="#ffad13" /></linearGradient>
          <filter id="glow"><feGaussianBlur stdDeviation="5" result="blur" /><feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge></filter>
        </defs>
        <g className="flow-source">
          <rect x="30" y="49" width="232" height="150" rx="15" fill="#191a1f" stroke="#474851" />
          <circle cx="51" cy="69" r="4" fill="#ff5f57" /><circle cx="65" cy="69" r="4" fill="#febc2e" /><circle cx="79" cy="69" r="4" fill="#28c840" />
          <rect x="50" y="91" width="112" height="12" rx="6" fill="#393a42" /><rect x="50" y="116" width="190" height="57" rx="8" fill="#24252b" />
          <path d="M44 116V96h20M248 116V96h-20M44 156v20h20M248 156v20h-20" fill="none" stroke="url(#orange)" strokeWidth="4" strokeLinecap="round" />
        </g>
        <path className="flow-line" d="M282 124H405" fill="none" stroke="#ff6a2a" strokeWidth="2" strokeDasharray="6 8" />
        <g className="flow-spark" filter="url(#glow)"><circle cx="470" cy="124" r="42" fill="#ff5c24" fillOpacity=".12" stroke="#ff6a2a" /><path d="M470 92l7 23 23 7-23 7-7 23-7-23-23-7 23-7z" fill="url(#orange)" /></g>
        <path className="flow-line flow-line-delay" d="M535 124H648" fill="none" stroke="#ff9b20" strokeWidth="2" strokeDasharray="6 8" />
        <g className="flow-output">
          <rect x="672" y="49" width="256" height="150" rx="15" fill="#17181c" stroke="#ff6a2a" /><rect x="687" y="65" width="226" height="118" rx="8" fill="url(#orange)" />
          <path d="M687 153l52-44 38 30 42-53 94 97H687z" fill="#fff" fillOpacity=".93" /><circle cx="739" cy="93" r="13" fill="#fff" fillOpacity=".9" />
          <rect x="765" y="211" width="89" height="26" rx="13" fill="#28292f" stroke="#494a53" /><text x="809.5" y="228" textAnchor="middle" fill="#f2f2f3" fontSize="12" fontFamily="var(--font-geist-mono)">1200 × 630</text>
        </g>
      </svg>
      {showDirectorNote && <div className="director-note" role="tooltip">Director note: the moving line makes the invisible handoff—from local capture to Codex generation—feel immediate.</div>}
    </div>
  );
}

export default function Home() {
  const playDemo = () => {
    document.querySelector('#demo')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    void document.querySelector<HTMLVideoElement>('#demo video')?.play().catch(() => {});
  };
  useEffect(() => {
    const context = (document as Document & { modelContext?: {
      registerTool: (tool: object, options: { signal: AbortSignal }) => void | Promise<void>;
    } }).modelContext;
    if (!context?.registerTool) return;
    const lifecycle = new AbortController();
    try {
      void Promise.resolve(context.registerTool({
        name: 'play_schnapshot_demo',
        description: 'Scroll to and play the ten-second SchnapShot demo, muted.',
        inputSchema: { type: 'object', properties: {}, additionalProperties: false },
        annotations: { readOnlyHint: false, untrustedContentHint: false },
        async execute(input: unknown) {
          if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).length) throw new Error('Expected an empty object.');
          const video = document.querySelector<HTMLVideoElement>('#demo video');
          if (!video) throw new Error('Demo is unavailable.');
          video.scrollIntoView({ behavior: 'instant', block: 'center' });
          video.muted = true;
          await video.play();
          return { playing: !video.paused, durationSeconds: 10 };
        },
      }, { signal: lifecycle.signal })).catch(() => {});
    } catch { /* Browsers without WebMCP retain the normal video controls. */ }
    return () => lifecycle.abort();
  }, []);
  return (
    <main>
      <nav className="nav shell" aria-label="Main navigation">
        <a className="brand" href="#top" aria-label="SchnapShot home"><img src="/icon.png" alt="" /><span>SchnapShot</span></a>
        <div className="nav-links"><a href="#workflow">Workflow</a><a href="#presets">Presets</a><a href="#privacy">Privacy</a><a href="https://github.com/Ansonhkg/SchnapShot">GitHub</a></div>
        <button className="nav-demo" onClick={playDemo}><Play size={14} fill="currentColor" /> Watch demo</button>
      </nav>

      <section className="hero shell" id="top">
        <div className="hero-copy">
          <h1>Your screenshot.<br /><span>Sized for the web.</span></h1>
          <p className="lede">An open-source Mac app that turns any screen selection into a polished, exact-size image using your own Codex account.</p>
          <div className="hero-actions"><button className="primary-button" onClick={playDemo}><Play size={17} fill="currentColor" /> Watch 10-second demo</button><a className="text-link" href="#workflow">See the workflow <ArrowDown size={16} /></a></div>
          <div className="trust-row"><span><Monitor size={15} /> Local Mac app</span><span><Sparkles size={15} /> Your Codex account</span><span><SlidersHorizontal size={15} /> Exact output sizes</span></div>
        </div>
        <div className="hero-stage" id="demo">
          <div className="size-tab"><span>Thumbnail</span> 1200 × 630</div>
          <div className="video-frame"><video autoPlay muted loop playsInline controls poster="/promo-poster.jpg" aria-label="Ten-second SchnapShot demo: capture a website, generate a thumbnail, and replace the original"><source src="/SchnapShot-interactive-1080p.mp4" type="video/mp4" /></video></div><div className="window-shadow" />
        </div>
      </section>

      <section className="metric-strip" aria-label="Product summary"><div className="shell metric-inner"><span><strong>⌥⌘4</strong> Capture an area</span><span><strong>1 click</strong> Choose a preset</span><span><strong>Exact</strong> width × height</span><span><strong>Ready</strong> on your clipboard</span></div></section>

      <section className="workflow shell section" id="workflow">
        <div className="section-heading"><div><h2>Capture. Generate. Ship.</h2></div><p>Skip the export dance. Your saved prompt and dimensions turn a rough screen selection into the asset the destination expects.</p></div>
        <CaptureFlow />
        <div className="steps"><article><span>1</span><div><h3>Capture an area</h3><p>Use your configurable shortcut, just like the Mac screenshot tool.</p></div></article><article><span>2</span><div><h3>Use a preset</h3><p>Choose the prompt and ratio you already saved for this destination.</p></div></article><article><span>3</span><div><h3>Copy and go</h3><p>Codex generates the result at the exact size and puts it on your clipboard.</p></div></article></div>
      </section>

      <section className="use-cases section"><div className="shell">
        <div className="section-heading narrow"><div><h2>Make the file the site wants.</h2></div></div>
        <div className="path-grid">{paths.map((path) => <article className="path-card" key={path.number}><div className="path-top"><span>{path.number}</span><Command size={18} /></div><div><p className="path-size">{path.size}</p><h3>{path.label}</h3><p>{path.detail}</p></div><div className="path-check"><Check size={14} /> Saved preset</div></article>)}</div>
      </div></section>

      <section className="presets shell section" id="presets">
        <div className="preset-copy"><h2>Your prompt and ratio,<br />saved together.</h2><p>Create a card for every destination. Click a card to use it. Hover to edit the name, prompt, width, and height.</p><ul><li><Check size={16} /> Three-column preset grid</li><li><Check size={16} /> Thumbnail and icon starters</li><li><Check size={16} /> Custom prompts and exact pixels</li></ul></div>
        <figure className="screenshot-card"><img src="/app-presets.png" alt="SchnapShot preset picker showing Thumbnail and Icon cards with sizes and prompts" /><figcaption>Pick a card. Capture. The rest is remembered.</figcaption></figure>
      </section>

      <section className="privacy section" id="privacy"><div className="shell privacy-panel"><div className="privacy-icon"><Clipboard size={26} /></div><div><h2>Local workflow. Your Codex account.</h2></div><div className="privacy-facts"><p>The Mac app handles capture, presets, output, and clipboard locally.</p><p>Only the screenshot you choose is sent to OpenAI for generation. Codex manages sign-in, and generation uses your Codex limits.</p></div></div></section>

      <section className="closing shell section"><img src="/icon.png" alt="SchnapShot orange shot-glass app icon" /><h2>From screenshot to anything.</h2><p>Open source. Build it on your Mac.<br />Requires macOS 14+ and Codex. Packaged download coming later.</p><a className="primary-button" href="https://github.com/Ansonhkg/SchnapShot"><Command size={18} /> Get the source</a></section>
      <footer className="shell footer"><a className="brand" href="#top"><img src="/icon.png" alt="" /><span>SchnapShot</span></a><p>Screenshot → Codex → clipboard.</p><p>macOS 14+</p></footer>
    </main>
  );
}
