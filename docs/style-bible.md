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

**One-sentence positioning** (TBD):

```
The game feels like _________________________________________________________
```

**3 reference games** (pick games whose mood/aesthetic we want to evoke; we are NOT copying gameplay):

| # | Game | What we steal |
|---|------|---------------|
| 1 | _e.g. INSIDE_ | _cold, minimalist atmosphere_ |
| 2 | _e.g. Hyper Light Drifter_ | _pixel art with melancholy palette_ |
| 3 | _e.g. Hollow Knight (early areas)_ | _quiet exploration tension_ |

---

## 2. Voice Guide

> How in-game text reads. Applies to: wall hints, UI prompts, ending screens, confirmation dialogs.

**Style rules** (extracted from PDF, please confirm):

- **Short sentences.** No paragraph-length narration.
- **Second person.** "You opened all the doors." not "The player has opened…".
- **No explanation.** State the consequence; let the player figure out the cause.
- **No exclamation marks.** Calm, observational tone.
- **Chinese primary, English subtitle for technical terms** (e.g. "失控值 Instability") — confirm if we want full bilingual or 中文 only.

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

### Base palette (TBD)

| Role | Hex | Notes |
|------|-----|-------|
| Background (maze floor) | `#______` | |
| Wall | `#______` | |
| Fog of war | `#______` | Probably near-black with low opacity |
| Player | `#______` | Must stand out against background |
| Chest / key / core (rewards) | `#______` | Inviting, warm |
| Real exit | `#______` | Subtle, easy to miss |
| Fake exit | `#______` | Obvious, slightly garish |

### Instability stage colors (most important)

These drive the HUD background and edge effects. Must read at a glance.

| Instability range | State | Color | Hex |
|-------------------|-------|-------|-----|
| 0–30 | 穩定 Stable | Green | `#______` |
| 31–60 | 擴張 Expanding | Yellow | `#______` |
| 61–80 | 扭曲 Distorting | Orange | `#______` |
| 81–99 | 崩壞 Collapsing | Red | `#______` |
| 100 | 失控 Lost | Deep red / black | `#______` |

> ⚠️ Make sure the green → red gradient is **monotonic in luminance** so it works for colorblind players.

---

## 4. Visual Style

> Pixel art? Vector? Hand-drawn? Decided here.

**Style direction** (TBD):

- [ ] **Pixel art** — resolution: ____×____ per tile (16×16? 24×24? 32×32?)
- [ ] **Vector / flat** — simple geometric shapes
- [ ] **Hand-drawn** — high effort, usually not jam-friendly

**2–3 reference images** (paste links or attach files):

1. `____________`
2. `____________`
3. `____________`

**Resolution decisions:**

- Window size: _____×_____
- Tile size: ____ × ____
- Map size: ____×____ tiles initial → expands to ____×____ at instability 100

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

- `[2026-MM-DD]` ___
- `[2026-MM-DD]` ___

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
