/* ═══════════════════════════════════════════════════════════════════════════
   MURO — muro.config.js
   This one file is your whole wall. Everything else is just the engine.

   HOW TO EDIT
   ───────────
   · Change a title, paste a new link, move a number → save → refresh.
   · Or move things visually: press E in the browser, drag/resize/rotate,
     then hit "⇩ Config" and it writes this exact file back out for you.
     Visual editing and vibe coding are the same loop.
   · Coordinates are absolute in "world" space. Regions are just coloured
     areas of that space — an item's `region` sets its accent colour and
     which chip zooms to it. Nothing is trapped inside a region.

   ITEM KINDS
   ──────────
   link   a URL. Live embed if the platform supports it, designed link card if not.
   words  a text block. tone: "manifesto" (big serif) or "plain".
   note   a paper note in your handwriting-ish mono. Editable in place.
   image  a picture. url = image url.

   TODO markers below are things only you can fill in.
   ═══════════════════════════════════════════════════════════════════════════ */

window.MURO_CONFIG = {

  identity: {
    name:    "Luk",
    tag:     "Life Is One · Amsterdam",
    seoTitle:"Luk — Life Is One",
    seoDesc: "La vida es una. One life, undivided. Builder, painter, musician, Amsterdam.",
  },

  /* Six wavelengths. One light. Change a hex and everything re-tunes. */
  regions: [
    { key:"one",   name:"ONE",   sub:"la vida es una",              color:"#F7F3EA", x:2000, y:1000, w: 900, h: 700 },
    { key:"make",  name:"MAKE",  sub:"code · products · ventures",  color:"#2E5BFF", x: 250, y: 250, w:1400, h: 900 },
    { key:"sound", name:"SOUND", sub:"music · vinyl · noise",       color:"#FF4D2E", x:2000, y:  60, w:1300, h: 800 },
    { key:"paint", name:"PAINT", sub:"canvas · colour · hands",     color:"#E4489B", x:3550, y: 250, w:1250, h: 900 },
    { key:"mind",  name:"MIND",  sub:"books · thinking · notes",    color:"#2F8F5B", x: 250, y:1500, w:1350, h: 900 },
    { key:"voice", name:"VOICE", sub:"podcast · words out loud",    color:"#F5A623", x:2050, y:1950, w:1250, h: 800 },
    { key:"life",  name:"LIFE",  sub:"amsterdam · people · style",  color:"#7B5CFF", x:3550, y:1500, w:1300, h: 950 },
  ],

  items: [

    /* ── ONE ─────────────────────────────────────────────────────────── */
    { id:"manifesto", region:"one", kind:"words", tone:"manifesto", x:2090, y:1150, w:720, h:420, rot:0,
      text:"I am not <em>an economist</em>.<br>I am not <em>a founder</em>.<br>I am not <em>a painter</em>, <em>a coder</em>, <em>a voice</em>.<br><br>I am the one life all of that happens in." },

    { id:"one-note", region:"one", kind:"note", x:2560, y:900, w:270, h:150, rot:-3,
      text:"la vida es una — you only get the one. so stop spending it being a single thing." },

    /* ── MAKE ────────────────────────────────────────────────────────── */
    { id:"venture", region:"make", kind:"words", tone:"plain", x:330, y:400, w:400, h:260, rot:-1,
      text:"<b>The venture builder.</b><br>My own platform for launching the ideas that won't leave me alone. Products, startups, experiments. Built in public, shipped fast, killed faster." },

    { id:"bhw", region:"make", kind:"words", tone:"plain", x:770, y:380, w:380, h:300, rot:1.2,
      text:"<b>Blue House World.</b><br>Co-founded it. It failed. It taught me more than the degree did — about people, about timing, about how much of a company is just conviction held long enough. I'd do it again. I <em>am</em> doing it again, better." },

    // TODO → swap for your real GitHub / product links
    { id:"gh", region:"make", kind:"link", x:340, y:720, w:340, url:"https://github.com/", title:"What I'm building this week", sub:"code, in public", rot:-1.5 },
    { id:"prod1", region:"make", kind:"link", x:720, y:730, w:360, url:"https://lifeisone.co", title:"Life Is One", sub:"this, and everything after it", rot:1 },

    { id:"make-note", region:"make", kind:"note", x:1160, y:520, w:250, h:170, rot:2.6,
      text:"vibe coding is not lesser coding. it's just building at the speed you think." },

    /* ── SOUND ───────────────────────────────────────────────────────── */
    // TODO → your actual tracks. Spotify / SoundCloud / Suno / Bandcamp all work.
    { id:"track1", region:"sound", kind:"link", x:2080, y:250, w:380,
      url:"https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT", title:"Latest track", sub:"", rot:-1.4 },
    { id:"track2", region:"sound", kind:"link", x:2520, y:230, w:340,
      url:"https://soundcloud.com/forss/flickermood", title:"Unreleased", sub:"made at 3am, kept anyway", rot:1.8 },
    { id:"vinyl", region:"sound", kind:"note", x:2920, y:270, w:290, h:210, rot:-2.4,
      text:"on the turntable this month:\n\n· \n· \n· \n\n(TODO: fill these in)" },
    { id:"sound-words", region:"sound", kind:"words", tone:"plain", x:2100, y:620, w:420, h:170, rot:.8,
      text:"<b>Sound.</b> I play. I record. I spin. Not for a career — because a room feels different when there's music in it, and I'd rather be the reason." },

    /* ── PAINT ───────────────────────────────────────────────────────── */
    // TODO → replace url with photos of your actual paintings
    { id:"paint1", region:"paint", kind:"image", x:3630, y:420, w:330, h:400, rot:-2,
      url:"", title:"Untitled" },
    { id:"paint2", region:"paint", kind:"image", x:4010, y:450, w:300, h:330, rot:1.6,
      url:"", title:"Untitled" },
    { id:"paint-words", region:"paint", kind:"words", tone:"plain", x:4360, y:430, w:360, h:250, rot:-1,
      text:"<b>Paint.</b> The only thing I make that nobody can ship, scale or A/B test. That's the point of it." },
    { id:"ig-paint", region:"paint", kind:"link", x:3660, y:880, w:340,
      url:"https://www.instagram.com/", title:"More on Instagram", sub:"9,000 of you are already here", rot:2 },

    /* ── MIND ────────────────────────────────────────────────────────── */
    { id:"reading", region:"mind", kind:"note", x:330, y:1660, w:300, h:230, rot:-2.2,
      text:"reading now:\n\n· \n· \n\nnext:\n· \n\n(TODO)" },
    { id:"mind-words", region:"mind", kind:"words", tone:"plain", x:690, y:1650, w:420, h:250, rot:1.4,
      text:"<b>Mind.</b> I started business economics at university. It's a title, not a self. The books I actually think with have almost nothing to do with it." },
    { id:"mind-quote", region:"mind", kind:"words", tone:"manifesto", x:340, y:1950, w:520, h:230, rot:-.6,
      text:"A degree is a <em>label</em>.<br>A life is a <em>range</em>." },

    /* ── VOICE ───────────────────────────────────────────────────────── */
    { id:"pod", region:"voice", kind:"words", tone:"plain", x:2120, y:2110, w:400, h:250, rot:-1.2,
      text:"<b>The podcast.</b> Coming. Conversations with people who refuse to be one thing either. If that's you, the door is open." },
    // TODO → swap for the real episode / trailer once it exists
    { id:"pod-link", region:"voice", kind:"link", x:2570, y:2130, w:360,
      url:"https://lifeisone.co", title:"Be on the first episode", sub:"tell me what you make", rot:1.6 },
    { id:"voice-note", region:"voice", kind:"note", x:2990, y:2200, w:260, h:170, rot:2.8,
      text:"say the thing out loud. it's less precious and more true than writing it." },

    /* ── LIFE ────────────────────────────────────────────────────────── */
    { id:"ams", region:"life", kind:"words", tone:"plain", x:3630, y:1660, w:400, h:230, rot:1.1,
      text:"<b>Amsterdam.</b> I live here, alone, on purpose. Small flat, good light, too many half-finished things on every surface." },
    { id:"ig", region:"life", kind:"link", x:4080, y:1650, w:340,
      url:"https://www.instagram.com/", title:"Instagram", sub:"9k · the loudest room I have", rot:-1.8 },
    { id:"life-note", region:"life", kind:"note", x:4460, y:1700, w:270, h:190, rot:2.2,
      text:"if you're in amsterdam and you make something — coffee, no agenda. just message me." },
    { id:"life-words", region:"life", kind:"words", tone:"manifesto", x:3640, y:1980, w:560, h:250, rot:-.8,
      text:"Come in.<br>Take your <em>shoes</em> off.<br>Look at the walls." },
  ],
};
