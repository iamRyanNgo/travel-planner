# Mobile & PWA System — a portable guide

How WhereToNext turns a single-file web app into something that feels like a
native mobile app: installable, offline-capable, gesture-driven, and correct
inside notches and home-bar insets. Everything here is lifted from the live
code so you can copy the patterns into another project (e.g. a life planner).

**Stack assumption:** vanilla HTML/CSS/JS, no framework, no build step. All of
this is plain DOM APIs and CSS — it drops into anything. Values are exact.

**The one-sentence philosophy:** *one responsive codebase, not a separate mobile
site* — a single `max-width:680px` breakpoint swaps the chrome (bottom nav for
top tabs, sheet for dropdown), turns on gestures, and respects the device's safe
areas; everything else is the same document.

---

## ▶ Paste this into the other project's session

Copy the block below verbatim into a Claude Code (or similar) session opened on
the project you want to make mobile-friendly. It tells the agent to read the rest
of this file and apply it, adapting the selectors to that codebase.

```text
Make this project mobile-friendly and installable as a PWA, using the patterns
in MOBILE.md (I'll paste its contents below, or it's in the repo root). Follow
the §10 porting checklist IN ORDER, adapting every selector/id in the snippets
to THIS codebase's actual markup — don't paste them blindly.

Before you start:
- Tell me the framework/build setup you find and how the doc's vanilla snippets
  map onto it (e.g. where the single breakpoint and global CSS should live, how
  the service worker + manifest get served, what the nav/tab/modal components
  are called here). If it's React/Vue/etc., translate the DOM/event patterns to
  the framework's idioms rather than adding raw addEventListener globals.
- Identify this app's real "primary destinations" for the bottom nav and its
  main scrollable content container for the swipe/pull-to-refresh gestures.

Then work in shippable increments, pausing after each so I can test on a phone:
  1. Foundations (§0) — viewport-fit=cover meta, iOS metas, 16px inputs,
     tap-highlight/touch-action.
  2. Safe areas (§1) — wrap every fixed top/bottom offset in env(safe-area-*).
  3. One breakpoint (§2) — add @media (max-width:680px); hide desktop-only
     chrome; tighten density.
  4. Bottom nav + collapsing header (§4).
  5. Bottom-sheet modals (§7).
  6. Touch targets (§6) — 44px floor on (pointer:coarse), focus-visible ring.
  7. PWA (§3) — manifest + maskable icon, network-first service worker, install
     button. Confirm the shell is served no-cache and sw.js no-store.

Stop after step 7 and check with me before adding gestures (§5), offline (§8),
or polish (§9) — those are opt-in per what the app needs.

Do NOT change any business logic, data model, or visual design language while
doing this — mobile plumbing only. After each step, verify it actually works
(load the page, check the DOM/CSS applied) rather than assuming.
```

If you can't attach the file, paste the whole of MOBILE.md right after that
block so the agent has the snippets inline.

---

## 0. The four things you must do first

These are non-negotiable foundations. Skip one and mobile feels broken no matter
how nice the rest is.

**1. The viewport meta — with `viewport-fit=cover`.** Without `cover`, the OS
letterboxes your app and `env(safe-area-inset-*)` always returns 0.

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
```

**2. iOS standalone meta** (so an installed icon opens chrome-less, with a
translucent status bar the app draws under):

```html
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
```

**3. 16px form inputs on mobile.** iOS Safari *zooms the page* when you focus an
input smaller than 16px. This one rule prevents the single most jarring mobile
bug:

```css
@media (max-width:680px){ input,select,textarea{ font-size:16px } }
```

**4. Kill the 300ms tap delay + grey tap flash** on every custom control:

```css
button, .tappable {
  -webkit-tap-highlight-color: transparent;
  touch-action: manipulation;   /* removes the double-tap-zoom wait */
}
```

---

## 1. Safe areas — draw edge-to-edge, pad by the insets

With `viewport-fit=cover` the app fills the whole screen, *including under* the
notch and the home-bar. You claw back usable space with the four
`env(safe-area-inset-*)` values, always wrapped in `max()`/`calc()` so a phone
with no notch still gets a sensible minimum.

```css
/* Fixed header extends into the notch, pads its content down past it */
@media (max-width:680px){
  #appHeader{
    padding: env(safe-area-inset-top,0) max(12px,env(safe-area-inset-right,12px))
             0 max(12px,env(safe-area-inset-left,12px));
    height: calc(58px + env(safe-area-inset-top,0px));
  }
  #root{ padding-top: calc(58px + env(safe-area-inset-top,0px)); }

  /* Scroll containers reserve room past the home bar */
  #dashboard,#tripView{
    padding: 16px 14px max(60px, calc(env(safe-area-inset-bottom,0px) + 24px));
  }
}

/* Bottom nav sits above the home bar */
.bottom-nav{ padding: 6px 4px calc(6px + env(safe-area-inset-bottom,0px)); }

/* Every floating control lifts above BOTH the bottom nav and the home bar */
.fab       { bottom: calc(72px + env(safe-area-inset-bottom,0px)); }
.toast     { bottom: max(24px, calc(env(safe-area-inset-bottom,0px) + 16px)); }
```

Rule of thumb: **anything `position:fixed` needs a safe-area term.** Top-anchored
things add `inset-top`; bottom-anchored things add `inset-bottom`.

---

## 2. Responsive strategy — one breakpoint, chrome swap

There is exactly **one** breakpoint: `@media (max-width:680px)`. Above it, the
desktop layout (top tab pills, dropdowns, hover). Below it, the phone layout.
The mobile block does three kinds of work:

1. **Swap navigation chrome** — hide the top tab slider, show a fixed bottom nav:
   ```css
   @media (max-width:680px){
     .trip-tabs-wrap{ display:none; }   /* top pills off */
     .bottom-nav{ display:flex; }       /* bottom bar on  */
   }
   ```
2. **Hide desktop-only affordances** — breadcrumb, button text labels, the
   desktop action cluster:
   ```css
   #breadcrumb{display:none} .btn-label{display:none} .ha-desktop{display:none!important}
   ```
   (Buttons keep their icon; the text label is what's hidden — `＋ Add` becomes `＋`.)
3. **Tighten density & grow touch targets** (see §6).

Everything else — the same HTML, same components — just reflows via
`grid-template-columns: repeat(auto-fit, minmax(Npx, 1fr))`.

---

## 3. PWA — installable + offline

Three files make the app installable and offline-capable.

### 3a. `manifest.json`

```json
{
  "name": "WhereToNext",
  "short_name": "WhereToNext",
  "start_url": "/",
  "display": "standalone",          /* chrome-less, like a native app */
  "background_color": "#080e1c",
  "theme_color": "#080e1c",
  "orientation": "any",
  "icons": [
    { "src": "/icons/icon.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "any" },
    { "src": "/icons/icon-maskable.svg", "sizes": "any", "type": "image/svg+xml", "purpose": "maskable" }
  ]
}
```
Linked from `<head>` with `<link rel="manifest" href="/manifest.json">`. The
**maskable** icon is what lets Android crop it into the platform's icon shape
without clipping your logo — provide a version with ~20% padding around the mark.

### 3b. Service worker — network-first HTML, cache-first assets

The strategy that avoids the classic PWA trap (users stuck on a stale build):

- **HTML navigation → network-first**, falling back to the last good copy only
  when offline. The page is never stale.
- **Scripts/fonts → cache-first** (stable, content rarely changes).
- **Images and live-data APIs → never cached** (avatars change; API data must be
  fresh).
- **Navigation preload** starts the HTML fetch in parallel with SW boot, so the
  worker adds ~0 latency.

```js
const CACHE = 'app-v6';   // bump to invalidate cached assets on deploy

self.addEventListener('activate', e => e.waitUntil(Promise.all([
  caches.keys().then(k => Promise.all(k.filter(x=>x!==CACHE).map(x=>caches.delete(x)))),
  self.registration.navigationPreload?.enable().catch(()=>{}),
  self.clients.claim(),
])));

self.addEventListener('fetch', e => {
  const {request} = e; const url = new URL(request.url);
  if (request.method !== 'GET') return;
  if (isLiveApi(url)) return;                       // supabase, weather, geo… → live
  if (request.mode === 'navigate') {                // HTML → network-first
    e.respondWith((async () => {
      try {
        const res = (await e.preloadResponse) || await fetch(request);
        if (res?.ok) (await caches.open(CACHE)).put('/', res.clone());
        return res;
      } catch { return (await caches.match('/')) || Promise.reject(); }
    })());
    return;
  }
  if (request.destination === 'image') return;      // never cache images
  e.respondWith(caches.open(CACHE).then(async c => { // assets → cache-first
    return (await c.match(request)) || fetch(request).then(r => { if(r.ok)c.put(request,r.clone()); return r; });
  }));
});
```

Register it and auto-reload once when a new worker takes control:

```js
if ('serviceWorker' in navigator) {
  let refreshing = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (!refreshing) { refreshing = true; location.reload(); }
  });
  navigator.serviceWorker.register('/sw.js');
}
```

> **Deploy note:** serve the HTML shell with `Cache-Control: no-cache` (revalidate,
> so unchanged visits are a cheap 304) and `sw.js` with `no-store`. If you keep
> un-hashed asset URLs (`/app.js`), remember to bump `CACHE` on each asset change
> — or switch those to stale-while-revalidate so they update without a bump.

### 3c. The install prompt (Android/Chrome)

Capture the browser's install event and surface your own button instead of the
default mini-infobar:

```js
let PWA_PROMPT = null;
window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); PWA_PROMPT = e; renderInstallButton(); });
window.addEventListener('appinstalled', () => { PWA_PROMPT = null; toast('App installed ✓'); });

async function installPWA(){
  if(!PWA_PROMPT) return;
  PWA_PROMPT.prompt();
  await PWA_PROMPT.userChoice;
  PWA_PROMPT = null;
}
```
Show the "⬇ Install App" button only while `PWA_PROMPT` is set (iOS never fires
this event — Safari installs via Share → Add to Home Screen, so don't rely on it
being present).

---

## 4. Navigation — bottom nav + overflow sheet

Phones navigate from the bottom (thumb reach), not the top. The pattern:

- **Fixed bottom bar** with the 4 primary destinations + a **"More"** button.
- The overflow destinations live in a **bottom sheet / modal grid** opened by More.
- The bar is translucent + blurred so content scrolls under it.

```css
.bottom-nav{
  display:none;                       /* desktop: hidden */
  position:fixed; left:0; right:0; bottom:0; z-index:90;
  background: color-mix(in srgb, var(--bg) 85%, transparent);
  backdrop-filter: blur(18px) saturate(1.4);
  border-top: 1px solid var(--border);
  padding: 6px 4px calc(6px + env(safe-area-inset-bottom,0px));
  justify-content: space-around;
}
@media (max-width:680px){ .bottom-nav{ display:flex } }
```

```js
const BOTTOM_PRIMARY = ['overview','itinerary','map','budget']; // the 4 thumb tabs
function bottomNavHTML(TABS){
  const prim = BOTTOM_PRIMARY.map(id => TABS.find(t=>t.id===id)).filter(Boolean);
  const overflowActive = !BOTTOM_PRIMARY.includes(CUR.tab);
  return `<nav class="bottom-nav">
    ${prim.map(t=>`<button class="bn-item${CUR.tab===t.id?' active':''}" onclick="setTab('${t.id}')">${icon(t)}<span class="bn-lbl">${t.label}</span></button>`).join('')}
    <button class="bn-item${overflowActive?' active':''}" onclick="openMoreTabs()">${moreIcon}<span class="bn-lbl">More</span></button>
  </nav>`;
}
```

**Collapsing header** — reclaim vertical space by sliding the top bar away on
scroll-down and back on scroll-up (mobile only):

```css
#appHeader{ transition: transform .22s ease; }
body.hdr-hide #appHeader{ transform: translateY(-100%); }
```
```js
let LASTY = 0, HIDDEN = false;
window.addEventListener('scroll', () => {
  if (!matchMedia('(max-width:680px)').matches) return;
  const y = scrollY, down = y > LASTY && y > 90;
  if (down !== HIDDEN) { HIDDEN = down; document.body.classList.toggle('hdr-hide', down); }
  LASTY = y;
}, {passive:true});
```

**Overflow menu / account menu** is a `position:fixed` panel portaled to
`<body>` (so it escapes any `overflow:hidden` ancestor), opened from the avatar.

---

## 5. Gestures — the native feel

All built on plain `touchstart`/`touchmove`/`touchend` (or Pointer Events for the
FAB). Register listeners as `{passive:true}` **except** where you must call
`preventDefault()` (drags, refresh commit).

### 5a. Swipe between tabs (with rubber-band)

Track a horizontal drag on the content area, let it follow the finger with a
resistive feel, and commit to the next/prev tab past a threshold. Guard against
the map, scrollers, inputs, and open modals.

```js
let SWIPE = null;
addEventListener('touchstart', e => {
  const t = e.touches[0], modal = !!modalRoot.innerHTML;
  SWIPE = (inTrip() && !modal &&
           !e.target.closest('#map,.hscroll,input,textarea,select,.dropdown'))
    ? {x:t.clientX, y:t.clientY, t:Date.now()} : null;
}, {passive:true});

addEventListener('touchmove', e => {
  if (!SWIPE) return;
  const t = e.touches[0], dx = t.clientX-SWIPE.x, dy = t.clientY-SWIPE.y;
  if (Math.abs(dx) > 18 && Math.abs(dx) > Math.abs(dy)*1.5) {   // horizontal intent
    SWIPE.tracking = true;
    const idx = TABS.indexOf(CUR.tab);
    const atEdge = (dx>0 && idx<=0) || (dx<0 && idx>=TABS.length-1);
    const pull = dx * (atEdge ? 0.12 : 0.35);                   // stiffer at the ends
    content.style.transform = `translateX(${pull}px)`;
    content.style.opacity = String(1 - Math.min(.3, Math.abs(pull)/420));
  }
}, {passive:true});

addEventListener('touchend', e => {
  if (!SWIPE) return;
  const t = e.changedTouches[0], dx = t.clientX-SWIPE.x, dy = t.clientY-SWIPE.y, dt = Date.now()-SWIPE.t;
  if (SWIPE.tracking){ content.style.transition='transform .22s cubic-bezier(.22,.9,.36,1),opacity .22s'; content.style.transform=''; content.style.opacity=''; }
  SWIPE = null;
  if (dt<600 && Math.abs(dx)>70 && Math.abs(dx) > Math.abs(dy)*2) {  // committed swipe
    const idx = TABS.indexOf(CUR.tab), next = dx<0 ? idx+1 : idx-1;
    if (next>=0 && next<TABS.length) setTab(TABS[next]);
  }
}, {passive:false});
```
Thresholds that feel right: **>18px** to *start* tracking, **>70px** and **<600ms**
and horizontal-dominant to *commit*.

### 5b. Pull-to-refresh

Only arm it when scrolled to the very top; show a pill; commit past ~80px.

```js
let PTR = null;
addEventListener('touchstart', e => { PTR = (scrollY<=2) ? {y0:e.touches[0].clientY, pulled:0} : null; }, {passive:true});
addEventListener('touchmove', e => {
  if (!PTR) return;
  PTR.pulled = e.touches[0].clientY - PTR.y0;
  if (PTR.pulled > 18 && scrollY <= 0) showPill(PTR.pulled>80 ? '↻ Release to refresh' : '↓ Pull to refresh');
}, {passive:true});
addEventListener('touchend', async () => {
  if (PTR && PTR.pulled>80 && scrollY<=0) { showPill('↻ Refreshing…'); await reloadData(); removePill(); toast('Refreshed ✓'); }
  PTR = null;
}, {passive:false});
```

### 5c. Long-press → action sheet

550ms hold on a card opens quick actions; a tiny haptic confirms; the trailing
click is swallowed so it doesn't also "open" the card.

```js
let LP_TIMER, LP_FIRED = false;
addEventListener('touchstart', e => {
  const card = e.target.closest('.card[data-id]');
  LP_FIRED = false; clearTimeout(LP_TIMER);
  if (card) LP_TIMER = setTimeout(() => { LP_FIRED = true; navigator.vibrate?.(10); openActionSheet(card.dataset.id); }, 550);
}, {passive:true});
addEventListener('touchmove', () => clearTimeout(LP_TIMER), {passive:true});
addEventListener('touchend', e => { clearTimeout(LP_TIMER); if (LP_FIRED){ e.preventDefault(); LP_FIRED=false; } }, {passive:false});
```

### 5d. Touch drag-and-drop (reorder across containers)

Hold a dedicated **handle** (not the whole card, or you can't scroll), clone a
"ghost" that follows the finger, highlight the drop target under the touch point,
and **auto-scroll** when the finger nears a screen edge. This needs
`preventDefault()` in `touchmove` (hence `{passive:false}`), so gate it behind an
explicit handle so normal scrolling stays passive.

```js
function touchDragMove(e){
  e.preventDefault();                       // page must not scroll under the drag
  const t = e.touches[0];
  positionGhost(t);
  markDropTarget(document.elementFromPoint(t.clientX, t.clientY));
  if (t.clientY < 110) scrollBy(0,-14);     // …but auto-scroll near the edges
  else if (t.clientY > innerHeight-110) scrollBy(0,14);
}
```

### 5e. Draggable FAB (Pointer Events)

The floating **＋** button can be repositioned: hold-drag it, it snaps to the
nearest side edge and remembers its spot. Uses Pointer Events + pointer capture,
a small movement threshold so taps still fire the action, and swallows the
post-drag click.

```js
function initFabDrag(){
  const el = document.getElementById('fab'); if(!el) return;
  applySavedPos(el);
  let sx=0, sy=0, ox=0, oy=0, drag=false;
  el.addEventListener('pointerdown', e => { sx=e.clientX; sy=e.clientY; const r=el.getBoundingClientRect(); ox=r.left; oy=r.top; drag=false; el.setPointerCapture(e.pointerId); });
  el.addEventListener('pointermove', e => {
    if (!el.hasPointerCapture(e.pointerId)) return;
    if (!drag && Math.hypot(e.clientX-sx, e.clientY-sy) < 8) return;   // a wobbly tap isn't a drag
    drag = true; el.style.transition='none';
    el.style.left = clamp(ox + e.clientX-sx) + 'px';
    el.style.top  = clamp(oy + e.clientY-sy) + 'px';
    el.style.right = 'auto'; el.style.bottom = 'auto';
  });
  el.addEventListener('pointerup', () => {
    if (!drag) return;
    el.addEventListener('click', c => { c.stopImmediatePropagation(); c.preventDefault(); }, {once:true, capture:true});
    snapToNearestEdge(el); savePos(el);
  });
}
```
The FAB itself needs `touch-action:none; user-select:none` so the browser doesn't
scroll/select while you drag it.

---

## 6. Touch targets & density

Fingers need ~44px; the mouse got away with less. Grow the small controls and
tighten spacing only on mobile:

```css
@media (max-width:680px){
  .btn.sm{ padding:9px 14px; min-height:40px; }
  .icon-chip{ min-height:36px; display:inline-flex; align-items:center; }
  .collapse-btn{ padding:10px; min-width:40px; min-height:40px; }
  .checkbox{ width:26px; height:26px; }
}
/* Everywhere, on finger devices: a hard floor + a visible focus ring */
@media (pointer:coarse){ .btn.sm, .tab, .icon-btn{ min-height:44px } }
button:focus-visible{ outline:none; box-shadow:0 0 0 3px var(--accent-soft); }
```

Also: `overflow-x` scrollers get `-webkit-overflow-scrolling:touch` and
`scroll-snap-type:x proximity` so horizontal rails (tab pills, chip rows) feel
native.

---

## 7. Bottom-sheet modals

On phones a centered dialog is wrong — dock it to the bottom and let it rise:

```css
@media (max-width:680px){
  .modal-bg{ padding:0; align-items:flex-end; }        /* dock to bottom */
  .modal{ border-radius:18px 18px 0 0; max-height:min(94vh,94dvh); }
}
```
Note **`dvh`** (dynamic viewport height) — it accounts for the mobile URL bar
that shrinks/grows as you scroll, where `vh` would overshoot. Keep the modal
header and footer `position:sticky` so the action buttons stay reachable while
the body scrolls, and trap focus inside (see the app's `modal()` for the full
a11y treatment: `role="dialog"`, focus trap, Escape, focus restore).

---

## 8. Offline behavior

Two layers cooperate:

1. **The service worker** keeps the app *shell* openable with no connection
   (last good HTML + cached assets).
2. **The app** caches its own *data* in `localStorage` (last-synced records) and
   an **outbox** of pending writes that flush when back online. On a failed
   fetch it falls back to the cached snapshot and shows a `📡 Offline` toast,
   so the itinerary stays readable on a plane.

Keep the data layer's cache writes **debounced/idle-coalesced** so you're not
serializing a big blob on every keystroke, and give each cache a size cap so it
can't blow the ~5MB `localStorage` quota (which would silently break the offline
cache).

---

## 9. Misc native-feel details

- **Haptics:** `navigator.vibrate?.(10)` on long-press fire and drag pickup — a
  10ms tick reads as "grabbed." Optional-chain it; desktop/iOS-Safari lack it.
- **No text selection on chrome:** `user-select:none` on buttons/nav so a
  long-press doesn't pop the selection UI.
- **`theme-color`** meta / manifest tints the Android status bar to match your
  app background.
- **Reduced motion:** honor it globally so the swipe/slide animations don't nauseate
  sensitive users:
  ```css
  @media (prefers-reduced-motion:reduce){ *,*::before,*::after{ animation-duration:.01ms!important; transition-duration:.01ms!important } }
  ```
- **Momentum containers:** anything scrollable inside a fixed element needs
  `-webkit-overflow-scrolling:touch`.

---

## 10. Porting checklist

Do these in order; each is independently shippable.

1. **Foundations (§0):** viewport `cover` meta, iOS metas, 16px inputs,
   `tap-highlight`/`touch-action`. *Instantly fixes the worst feel.*
2. **Safe areas (§1):** wrap every `position:fixed` top/bottom offset in
   `env(safe-area-inset-*)`.
3. **One breakpoint (§2):** add `@media (max-width:680px)`; hide desktop-only
   chrome, tighten density.
4. **Bottom nav (§4):** move primary navigation to a fixed bottom bar + More
   sheet; add the collapsing header.
5. **Bottom-sheet modals (§7):** dock dialogs to the bottom, `dvh`, sticky
   footer.
6. **Touch targets (§6):** 44px floor on `(pointer:coarse)`, focus-visible ring.
7. **PWA (§3):** manifest + maskable icon, the network-first service worker,
   the install button.
8. **Gestures (§5), à la carte:** swipe-tabs and pull-to-refresh give the biggest
   native-feel payoff for the least code; add long-press, touch-DnD, draggable FAB
   as the app needs them.
9. **Offline (§8):** SW shell + localStorage data cache + outbox.
10. **Polish (§9):** haptics, reduced-motion, theme-color.

Steps 1–2 alone move an app from "a website on a phone" to "feels intentional."
1–7 get you to "installable app." Add 8–10 and it's indistinguishable from native
for most users.
