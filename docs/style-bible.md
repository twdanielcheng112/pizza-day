# Style Bible — 《失控視界 Unbounded Vision》

> **Status**: 🟡 R0 deliverable — to be filled in during M0 (Style Bible) milestone, before code work on M1 starts.
> **Owner**: TBD (assign at first team sync)
> **Hard time-box**: 1 day, max 1.5 days. **Done > perfect.**

This document is the **single source of truth** for the game's visual + audio + voice identity. Once R0 is locked, R1–R3 work executes against this bible without re-debating direction.

---

## 0. Why this exists

The team will be making **art and music in parallel with code**. Without a shared aesthetic constraint, parallel work produces inconsistent output that has to be redone. This bible exists so that an artist or musician can start working **without asking another team member** what the game should feel like.

If you find yourself adding "we should also decide X" to this doc and you're more than 1 day in — stop. Ship what's here, iterate later.

---

## 1. Tone Definition

> One sentence + 3 reference games. Done in 30 minutes.

**One-sentence positioning:**

```
The game feels like not-too-sweet cotton candy with something quietly wrong inside —
a pastel maze that watches you ruin yourself, one open door at a time.
```

中文意譯：像不太甜的棉花糖，裡面藏著哪裡不對勁 — 一座柔和粉色的迷宮，安靜地看著你一扇門一扇門地把自己毀掉。

**3 reference games** (mood/aesthetic only — we are NOT copying gameplay):

| # | Game | What we steal |
|---|------|---------------|
| 1 | **Inscryption** | The game itself warps as the player "succeeds" — same mechanical-horror DNA as our Instability system |
| 2 | **OMORI** | Soft pastel palette + calm voice describing unsettling events — locks both visual register and writing tone |
| 3 | **Yume Nikki** | Wordless dreamlike maze exploration with limited UI — matches our fog-of-war, walk-driven core loop |

---

## 2. Voice Guide

> How in-game text reads. Applies to: wall hints, UI prompts, ending screens, confirmation dialogs.

**Style rules** (locked R0):

- **Short sentences.** No paragraph-length narration. Canonical lines all fit in one breath.
- **Second person.** 「你打開了所有門」，不是「玩家打開了所有門」。
- **No explanation.** State the consequence; let the player figure out the cause.
- **No exclamation marks.** Calm, observational tone — the voice never raises itself.
- **「邊界」 is a speaking subject, not inert geometry.** Grant it intent with verbs like 記住、推移、擴張、改寫. Avoid passive constructions ("the maze was changed"); the maze acts, the player is acted on.
- **中文 primary, English only for stat/technical terms.** Stat labels are bilingual (「失控值 Instability」、「視野 Vision」、「成就 Achievement」) so jam judges can map the mechanic at a glance. Narrative text, wall hints, prompts, and ending lines stay **中文 only** — bilingual subtitles break the atmosphere.

**Canonical examples** (from PDF):

```
「你已擴張得太遠。」
「邊界已無法收回。」
「看得越遠，越找不到出口。」
「不是所有門都該被打開。」
「邊界會記住你的貪婪。」
「你打開了所有門。你看見了整座迷宮。你得到了所有獎勵。但邊界再也無法停止向外推移。」
「你逃出去了。但你仍然帶走了迷宮的一部分。」
「你沒有征服迷宮。你只是學會了停止。」
```

**Anti-examples** (please don't write these):

```
❌ "Game Over! Better luck next time!"
❌ "You collected 5 chests. Awesome job!"
❌ "Warning: Instability is rising. Please be careful."
```

---

## 3. Color Palette

> 5–7 colors. Hex codes. **Instability stage colors are critical** — they drive the HUD's reversal signal.

Direction inherits §1 + §8: *not-too-sweet cotton candy*, OMORI register, pastel surface hiding unease. Saturation stays low across the base palette; the **only** colors allowed to be punchy are the instability stages 3–5 (the "unease made visible").

### Base palette

| Role | Hex | Notes |
|------|-----|-------|
| Background (maze floor) | `#F0E8DC` | Warm cream — OMORI dream-room neutral, slightly warm so the maze never reads cold |
| Wall | `#A98DAE` | Muted mauve — readable against floor without harsh contrast |
| Fog of war | `#2A1F2E` | Deep plum near-black — **never pure black** (pure black against pastels feels wrong) |
| Player | `#E89BA0` | Anxious coral — pops against cream by saturation, not luminance |
| Chest / key / core (rewards) | `#F4C8A8` | Tempting peach — "looks like you want to pick it up" |
| Real exit | `#B8D4C2` | Faded mint — deliberately low-presence; easy to walk past |
| Fake exit | `#D8A8C8` | Pink-lavender — slightly more saturated than real exit; "look again" pull, still in pastel family |

### Instability stage colors (most important)

These drive the HUD edge effects and stat color. Must read at a glance and stay legible under colorblind conditions.

| Instability range | State | Color name | Hex | Luminance (Y) |
|-------------------|-------|------------|-----|---------------|
| 0–30 | 穩定 Stable | Pale sage | `#C8E0BC` | 216 |
| 31–60 | 擴張 Expanding | Butter yellow | `#E8C870` | 200 |
| 61–80 | 扭曲 Distorting | Dusty coral | `#D89060` | 156 |
| 81–99 | 崩壞 Collapsing | Brick red | `#B85060` | 103 |
| 100 | 失控 Lost | Oxblood | `#4A1828` | 36 |

> ✅ **Luminance is monotonically decreasing** (ITU-R BT.709 weights), ~50-step drops between stages. Colorblind players can resolve the state from brightness alone; hue rotation (green → yellow → orange → red) is the second signal, not the only one.

**Design rule:** as instability rises, saturation goes **up** and value goes **down**. That visual move — "color thickens" — is the literal rendering of §1's "pastel surface hiding something quietly wrong." Do not invert this curve in subsequent UI work.

---

## 4. Visual Style

> Pixel art? Vector? Hand-drawn? Decided here.

**Style direction:** **Pixel art**, pastel-tinted, soft shading — OMORI / Yume Nikki register. Inherits §1 ("cotton candy with quiet unease") and §8 frozen decision. Vector / flat rejected (loses pixel texture); hand-drawn rejected (not jam-friendly).

**2–3 reference images** (search keywords for the artist; replace with attached files once collected):

1. **OMORI — WHITE SPACE / Headspace rooms** — pastel cream + mauve + coral interiors that read calm-yet-uncanny. Search: `omori whitespace tile` / `omori headspace screenshot`
2. **Yume Nikki — Number Worlds / The Mall** — limited-palette dreamscapes; geometric tile repetition builds dread without detail. Search: `yume nikki number world tiles`
3. **OneShot — Pepper's House / Glen** — pastel pixel exploration + melancholy isolation; same fog-of-war exploration mood as our maze. Search: `oneshot pepper's house pixel`

**Resolution decisions:**

- Window size: **1280×720** (standard 720p — runs on any jam-judge machine)
- Internal viewport: **640×360** (Godot pixel-perfect 2× integer scale to window)
- Tile size: **24×24** source pixels (effective on-screen ≈ 48×48 after 2× scale)
- Map size: initial **20×15 tiles** (fills the viewport so fog reads claustrophobic from the start) → expands to **~35×25 tiles** at instability 100 (camera follows the player beyond initial bounds). Treat these as R1 starting numbers — refine in playtest.

---

## 5. UI Font

> One Chinese font + one English font. Must be free / commercial-OK for jam submission.

| Use | Font | Notes |
|-----|------|-------|
| Chinese body | `____________` | e.g. 思源黑體 / 源樣明體 |
| English body | `____________` | e.g. JetBrains Mono / Inter |
| Numbers (HUD stats) | `____________` | Monospace recommended for stat readout |
| Ending title | `____________` | Can be more decorative |

**License check**: confirm every font is OFL or Apache-2.0 / similar before shipping.

---

## 6. Music Direction

> One sentence + one reference track.

**One-sentence direction** (TBD):

```
The music feels like __________________________________________________________
```

**Reference track** (link or describe):

```
__________________________________________________________
```

**Cue list** (what music we actually need for MVP):

| Cue | When | Length | Style |
|-----|------|--------|-------|
| Ambient loop (gameplay) | Whole game | ~60s loop | Calm, drone-y |
| Instability sting — Stage 1 (≥31) | One-shot at first trigger | ~3s | Subtle warning |
| Instability sting — Stage 2 (≥61) | One-shot at first trigger | ~3s | Tense, dissonant |
| Instability sting — Stage 3 (≥81) | One-shot at first trigger | ~3s | Alarming |
| Bad ending music | Ending screen | ~20s | Final, oppressive |
| Normal ending music | Ending screen | ~20s | Bittersweet |
| True ending music | Ending screen | ~20s | Calm, resolved |

---

## 7. First Batch Deliverables (the proof that R0 works)

By end of M0, the following must exist as actual files in the repo:

- [ ] `assets/tiles/floor.png` — floor tile in committed style
- [ ] `assets/tiles/wall.png` — wall tile in committed style
- [ ] `assets/sprites/player.png` — player sprite (idle frame is enough)
- [ ] `assets/sprites/chest.png` — closed + open variants
- [ ] `assets/sprites/exit_real.png` + `assets/sprites/exit_fake.png` — clearly distinguishable
- [ ] `assets/audio/ambient_loop.ogg` — 30s seamless loop

> If we hit time-box and these aren't done — ship placeholder colored squares and move on. The bible itself takes priority over the first batch.

---

## 8. Frozen decisions log

Record any decision made during R0 here. Format: `[YYYY-MM-DD] decision — reason`.

- `[2026-05-23]` Tone locked = "not-too-sweet cotton candy with quiet unease" (psychological-horror branch, OMORI visual register) — pre-commits §3 palette mood (pastel, low saturation) and §4 visual direction (OMORI-like soft pixel/flat) so T0.3 / T0.4 don't re-debate the surface feel. References: Inscryption, OMORI, Yume Nikki.
- `[2026-05-23]` Voice locked = 中文 primary, English only on stat labels (失控值 Instability / 視野 Vision / 成就 Achievement). 「邊界」 is a speaking subject with agency. Affects HUD label widths (T0.5 font sizing must fit bilingual stat names) and all wall-hint / ending text (中文 only, no English subtitles).
- `[2026-05-23]` Palette locked = warm cream floor + muted mauve walls + plum-tinted fog (never pure black), with rewards in tempting peach and a deliberately low-presence faded-mint real exit. Instability stages span pale-sage → butter-yellow → dusty-coral → brick-red → oxblood, with **strictly monotonic decreasing luminance** (216 → 200 → 156 → 103 → 36) so the HUD reads under colorblind conditions. Saturation rises and value falls with instability — "color thickens" is the rule, do not invert.
- `[2026-05-23]` Visual locked = pixel art at **24×24 source pixels**, rendered 2× via Godot pixel-perfect integer scaling into a **1280×720** window (640×360 internal viewport). Initial maze 20×15 tiles → expands to ~35×25 at instability 100. References: OMORI (WHITE SPACE / Headspace), Yume Nikki (Number Worlds), OneShot. Constrains M1 (TileMap cell size = 24), M2 (Camera2D zoom = 2, follows player), and the artist's tile authoring template.

---

## 9. Out of scope for R0

These will be decided later (R1 or R2). Do NOT block R0 on them:

- Detailed animation frames (R1 ships idle-only sprites)
- Multiple chest tiers / inventory icons (R3 if at all)
- Cinematic ending art (text-only endings in R1)
- Particle effects
- Full soundtrack — only the cues in section 6 are MVP

---

**When this doc is full → mark this file's status header to 🟢 and start M1.**
