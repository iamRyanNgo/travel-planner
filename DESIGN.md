# WhereToNext — Design System

A portable reference for the visual language of WhereToNext, written so the same
look can be rebuilt on another product (e.g. a life planner). Everything below
is lifted from the live CSS — values are exact, not approximations.

**Personality in one line:** *refined dark editorial* — a rich near-black canvas,
one champagne-gold accent, an elegant serif for display type, and frosted
"liquid glass" surfaces when content sits over imagery.

---

## 1. Principles

1. **Dark is the default.** The app opens in dark mode; light mode is an opt-in
   "soft daylight," not stark white.
2. **One accent.** Champagne gold is the only brand color. It marks primary
   actions, active states, key numbers, and nothing else. Everything else is
   neutral or a muted category color.
3. **Serif for feeling, sans for function.** Display type (titles, big numbers)
   is a high-contrast serif; all UI text, labels, and data are Inter.
4. **Content wears emoji, chrome wears line icons.** Navigation and buttons use
   1.7px-stroke SVG icons; user content (activities, food, hotels) keeps warm
   emoji. This separates "the app" from "your stuff."
5. **Glass belongs over photos.** The frosted-glass treatment only activates
   when a photo backdrop exists — glass over flat color is just gray.
6. **Quiet motion.** Transitions are 120–250 ms, ease-out, and always attached
   to a user action. Nothing animates on its own.

---

## 2. Color tokens

Define once on `:root` (dark = default), override under `[data-theme="light"]`.

### Dark (default)

```css
:root {
  /* canvas */
  --bg:     #0b0d11;   /* page background — near-black, slightly blue */
  --bg2:    #0f1217;   /* alt background (subtle stripes, wells) */
  --panel:  #14171d;   /* card surface */
  --panel2: #1b1f27;   /* nested surface: inputs, hover fills, chips */
  --border: #23262e;   /* hairline borders */
  --border2:#2f333d;   /* stronger borders: buttons, active edges */

  /* text */
  --text:  #edeff3;    /* primary */
  --muted: #8b93a1;    /* secondary */
  --dim:   #4d5460;    /* tertiary / placeholders */

  /* the accent */
  --gold:  #d9b877;    /* champagne gold — the only brand color */
  --gold2: #f0d9a4;    /* lighter gold for gradient tops */
  --accent-soft: rgba(217,184,119,.12);  /* focus rings, soft fills */

  /* muted category palette (never for chrome, only to code content) */
  --blue:#7aa0dc; --cyan:#5ec4d2; --green:#5cc295; --coral:#e28479;
  --purple:#ab97e0; --orange:#e0a066; --pink:#dd8bb4;

  /* shape + depth */
  --radius: 16px;
  --shadow:    0 1px 2px rgba(0,0,0,.3), 0 14px 40px -14px rgba(0,0,0,.6);
  --shadow-sm: 0 1px 3px rgba(0,0,0,.35);
}
```

### Light ("soft daylight" — warm greige, deliberately not white)

```css
[data-theme="light"]{
  --bg:#e5e3dd; --bg2:#dddad2; --panel:#f0eee9; --panel2:#e8e5df;
  --border:#d2cec3; --border2:#c3beb1;
  --text:#22262e; --muted:#5f6470; --dim:#9b978c;
  --gold:#a97e2e; --gold2:#c99a44;               /* deepened for contrast */
  --blue:#3a6cc0; --cyan:#0e8ba0; --green:#2e9c6f; --coral:#cf5b4d;
  --purple:#7c5fd0; --orange:#c47a2e; --pink:#c25a94;
  --shadow:0 1px 2px rgba(60,50,30,.06), 0 14px 40px -18px rgba(60,50,30,.22);
  --shadow-sm:0 1px 3px rgba(60,50,30,.08);
  --accent-soft:rgba(169,126,46,.10);
}
```

### Usage rules

- Gold = primary buttons, active tab, key stats, "confirmed/positive" moments.
- Semantic status: green = confirmed/safe, orange = deadline approaching,
  coral = danger/overdue, muted/dim = expired or inactive.
- Category colors tint *icons and badges only*, never large fills.

---

## 3. Typography

| Role | Font | Details |
|---|---|---|
| Display (h1–h3, big numbers) | **Cormorant Garamond** 700 | fallback `Georgia, serif`; letter-spacing 0 |
| Logo wordmark | **Fraunces** 700 | 22px, letter-spacing −.6px, `font-variation-settings:'opsz' 144` |
| Everything else | **Inter** 400/450/500/600/700 | letter-spacing −.1px on body |

```css
body { font-family:'Inter',system-ui,-apple-system,sans-serif;
       -webkit-font-smoothing:antialiased; letter-spacing:-.1px }
h1,h2,h3 { font-family:'Cormorant Garamond',Georgia,serif;
           font-weight:700; letter-spacing:0 }
```

Scale in practice: section titles 16–17px (serif), card titles 17px/700,
stat numbers 28–30px serif in gold, body 13–14px, metadata 12px muted,
micro-labels 10–11px.

**The label pattern** (used on every form field and stat tile):

```css
label { font-size:11px; color:var(--muted); font-weight:600;
        letter-spacing:.7px; text-transform:uppercase; margin-bottom:6px }
```

Tiny uppercase muted labels + normal-case content is a core part of the look.

**Serif ≠ everywhere:** dates inside lists and category headers use Inter
(16px/700), because the serif gets clunky at small sizes in dense UI. Reserve
it for headings and hero numbers.

---

## 4. Shape, spacing, depth

- **Radius:** cards 16px (`--radius`), buttons & inputs 11px, small chips
  9–10px, pills fully rounded (20–30px).
- **Card:** `background:var(--panel); border:1px solid var(--border);
  border-radius:var(--radius); padding:20px; box-shadow:var(--shadow-sm)`.
- **Depth comes from borders + soft shadows,** not brightness jumps. Nested
  elements step `--panel` → `--panel2`, never lighter than that.
- Section spacing: cards separated by 16px; page sections by 32–44px.
- **Section header pattern** (title left, action right):

```css
.section-head { display:flex; align-items:center; justify-content:space-between;
                margin-bottom:16px; flex-wrap:wrap; gap:10px }
```

- **Elegant divider** (the "Past Adventures" pattern — label with a hairline
  running to the right edge):

```css
.divider { display:flex; align-items:center; gap:16px; margin:44px 0 22px }
.divider::after { content:''; flex:1; height:1px; background:var(--border) }
.divider span { font-family:'Cormorant Garamond',serif; font-size:19px;
                font-weight:600; color:var(--muted); white-space:nowrap }
```

---

## 5. Liquid glass (the signature move)

When a page has a photo (a trip's banner), the whole page gets a blurred
photo backdrop and every card turns translucent frosted glass. Two parts:

**A. Fixed blurred backdrop** behind everything:

```css
#pageBg { display:none; position:fixed; inset:-20px; z-index:-2;
  background-size:cover; background-position:center;
  filter: blur(8px) saturate(1.25) brightness(.95);
  transform: scale(1.04);   /* hides blur-edge fringing */ }
```

**B. Cards become glass** (scoped by a body class, e.g. `body.photo-open`):

```css
body.photo-open .card {
  background: color-mix(in srgb, var(--panel) 46%, transparent);
  backdrop-filter: blur(40px) saturate(1.7);
  -webkit-backdrop-filter: blur(40px) saturate(1.7);
  border-color: color-mix(in srgb, var(--border2) 60%, transparent);
}
/* legibility: brighten secondary text over glass */
body.photo-open { --muted:#c2c9d4; --dim:#93a0b0 }
[data-theme="light"] body.photo-open { --muted:#4a4f5a; --dim:#7a7f8a }
[data-theme="light"] body.photo-open .card {
  background: color-mix(in srgb, #fff 58%, transparent);
}
```

Hard-won rules:
- **Bump `--muted`/`--dim` when glass is active** — otherwise secondary text
  disappears against the photo.
- Inner elements (rows inside a glass card) go *flat* — don't stack glass on
  glass.
- The backdrop blur is mild (8px) so the photo stays recognizable; the *card*
  blur is heavy (40px) so text stays readable.

---

## 6. Components

### Buttons

```css
.btn { display:inline-flex; align-items:center; gap:7px; padding:10px 17px;
  border-radius:11px; font-size:13px; font-weight:600; letter-spacing:.2px;
  border:1px solid var(--border2); background:var(--panel2); color:var(--text);
  transition: background .15s, border-color .15s, transform .12s }
.btn:active { transform:scale(.97) }              /* tactile press */

.btn.primary { background:linear-gradient(160deg,var(--gold2),var(--gold));
  border-color:var(--gold); color:#1c1503; font-weight:700;
  box-shadow:0 4px 14px -4px rgba(217,184,119,.5) }

.btn.ghost  { background:transparent; border-color:transparent }
.btn.ghost:hover { background:var(--panel2) }

.btn.danger { background:transparent; color:var(--coral);
  border-color:color-mix(in srgb,var(--coral) 40%,transparent) }
.btn.danger:hover { background:color-mix(in srgb,var(--coral) 12%,transparent) }
```

Primary = gold gradient with dark-brown text (`#1c1503`) — never white on gold.
Destructive = outlined coral, only fills on hover. One primary per view.

### Inputs

```css
input, textarea, select { background:var(--panel2); border:1px solid var(--border);
  color:var(--text); border-radius:11px; padding:10px 13px; font-size:14px;
  transition: border-color .15s, box-shadow .15s }
input:focus { border-color:var(--gold); box-shadow:0 0 0 3px var(--accent-soft) }
input::placeholder { color:var(--dim) }
```

Focus = gold border + a 3px soft-gold ring. No default blue outlines anywhere.

### Status badges

```css
.badge { font-size:10px; font-weight:700; padding:2px 8px; border-radius:6px;
         letter-spacing:.5px; text-transform:uppercase }
/* tint with a status color at low opacity + solid text of the same color */
```

### Toast (feedback)

Pill anchored bottom-center, gold border, slides up:

```css
.toast { position:fixed; bottom:24px; left:50%; transform:translateX(-50%);
  background:var(--panel2); border:1px solid var(--gold); color:var(--text);
  padding:12px 22px; border-radius:30px; font-weight:600; font-size:14px;
  box-shadow:var(--shadow); animation:toastIn .25s ease-out }
```

Copy style: short + affirming — `Saved ✓`, `Trip created! 🎉`.

### Modals

- Backdrop `rgba(0,0,0,.7)` + `backdrop-filter:blur(4px)`, content centered.
- Sticky header (title + ✕) and sticky footer (Cancel left of a single gold
  primary; destructive action far-left).
- Close on backdrop click **only if the press started on the backdrop** (so
  drag-selecting text in an input can't dismiss it).

### Dropdown menus

Small floating panel: `background:var(--panel); border:1px solid var(--border2);
border-radius:14px; padding:6px; box-shadow:0 16px 48px rgba(0,0,0,.7)`.
Items are full-width quiet buttons (14px/500) with an emoji prefix; sections
split by a 1px `--border` hr.

### Empty states

Centered, generous padding, dashed-free (uniform 1px border), an oversized
emoji, one sentence of guidance:

```css
.empty { text-align:center; padding:52px 24px; color:var(--muted);
         border:1px solid var(--border); border-radius:var(--radius) }
```

### Stat tiles

Big serif number in gold over a tiny uppercase muted label:

```
28–30px Cormorant 700 var(--gold)
10px uppercase .7ls var(--muted)
```

---

## 7. Navigation chrome

- **Header:** fixed, 60px, translucent + blurred —
  `background:color-mix(in srgb,var(--bg) 82%,transparent);
  backdrop-filter:blur(18px) saturate(1.4); border-bottom:1px solid var(--border)`.
  Contains: logo (wordmark + 9.5px uppercase tagline at 2.6px letter-spacing),
  actions right (notification bell, avatar chip → dropdown).
- **Tabs:** pill buttons (8px 14px, radius 10px, 13px/600); active = gold text
  on `--accent-soft` fill. On mobile the tab row is sticky under the header and
  horizontally scrollable.
- **Mobile bottom nav:** 4 primary tabs + "More" sheet; blurred translucent bar
  with `env(safe-area-inset-bottom)` padding; 10px labels under stroke icons.
- **FAB (mobile):** 56px, radius 18px, gold gradient, bottom-right.
- **Header hides on scroll-down, returns on scroll-up** (`transform:
  translateY(-100%)`, .22s ease) — content gets the room.
- Browser history is wired to views/tabs so Back/Forward work like a website.

---

## 8. Iconography

- **Chrome icons:** inline SVG, `stroke-width:1.7`, `stroke-linecap/join:round`,
  `fill:none`, `stroke:currentColor`, 24px viewBox (lucide-style). Used for
  tabs, nav, and category markers on cards.
- **Content icons:** emoji (🏨 ✈️ 🍜 📍 …). Emoji stay in menus, section
  titles, and user-generated rows — they keep the product warm.
- Notification dot: coral circle, 10px bold count, ringed with the bg color
  (`box-shadow:0 0 0 2px var(--bg)`).

---

## 9. Motion

- Standard transition: `.15s` on background/border/color; `.12s` transform.
- Press feedback: `transform:scale(.97)` on `:active`.
- Panels/pills entering: `pplIn .2s ease-out` (fade + 4px rise).
- Tab content: directional slide-in — from the right when moving to a later
  tab, from the left when moving back.
- Respect the tap: `-webkit-tap-highlight-color:transparent` +
  `touch-action:manipulation` on all custom buttons.

---

## 10. Theming mechanism

- Theme = `data-theme` attribute on `<html>`; dark is the absence of it.
- Preference in `localStorage` (`'<app>-theme'`), applied by a tiny inline
  script **in `<head>`** so there's no flash of the wrong theme:

```html
<script>(function(){try{
  if(localStorage.getItem('app-theme')==='light')
    document.documentElement.dataset.theme='light';
}catch(e){}}())</script>
```

- The toggle lives quietly in the account dropdown, not the header.

---

## 11. Voice & microcopy

- Friendly, brief, second person: "Nothing scheduled today — enjoy the
  freedom! 🏖"
- Emoji punctuate, they don't decorate — one per message, at the front or end.
- Uppercase micro-labels for structure; sentence case everywhere else.
- Warnings are specific and calm: "Free cancellation ends TOMORROW", not ⚠️⚠️.

---

## 12. Porting checklist (for the life planner)

1. Copy the token blocks (§2) verbatim; swap `--gold`/`--gold2` only if you
   want a different accent — keep everything else neutral.
2. Load the three fonts (Google Fonts): `Cormorant Garamond 500–700`,
   `Inter 400–700`, `Fraunces 600–700` (logo only). Preload + swap.
3. Apply §3 body/heading/label rules globally, then build §6 components.
4. Keep one gold primary action per screen; status colors per §2 rules.
5. Add the glass treatment (§5) only where a user photo/banner exists.
6. Use the flash-free theme init (§10), dark default.
7. Steal the details that make it feel finished: `:active` scale, gold focus
   rings, the labeled divider, sticky modal footers, and the toast pill.
