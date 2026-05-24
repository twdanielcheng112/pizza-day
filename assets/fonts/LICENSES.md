# Font Licenses

All fonts shipped in this directory are jam-safe (free for commercial use,
no attribution gymnastics required for game-jam submission). Each font's
upstream LICENSE file is linked below — copy them into this folder if the
jam submission checklist asks for a verbatim license file alongside the
binary.

## Noto Serif CJK TC — `NotoSerifTC-Regular.otf`, `NotoSerifTC-Black.otf`

- **Author**: Adobe Inc. + Google Inc. (Source Han Serif TC and Noto Serif
  CJK TC are the **same font family** released under two different brand
  names from one joint project — identical glyphs, identical OFL license).
  The style bible §5 says "Source Han Serif TC"; we ship the Noto-branded
  build because individual subset OTFs are downloadable per weight from the
  upstream repo, whereas Adobe only distributes the family as a 138 MB zip.
- **License**: SIL Open Font License 1.1 (OFL-1.1)
- **Upstream LICENSE**: https://github.com/notofonts/noto-cjk/blob/main/Serif/LICENSE
- **Project page**: https://github.com/notofonts/noto-cjk
- **Used for**: 中文 body text (Regular) and ending titles (Black; equivalent
  to Source Han Serif's Heavy weight — Noto uses Black/Bold/Medium naming).
  明體 serifs carry the "literary observer" register the style bible §5 locks.

## Inter — `Inter-Regular.otf`

- **Author**: Rasmus Andersson
- **License**: SIL Open Font License 1.1 (OFL-1.1)
- **Upstream LICENSE**: https://github.com/rsms/inter/blob/master/LICENSE.txt
- **Project page**: https://github.com/rsms/inter
- **Used for**: English body text (currently the English half of bilingual
  stat labels, e.g. "失控值 Instability").

## JetBrains Mono — `JetBrainsMono-Regular.ttf`

- **Author**: JetBrains s.r.o.
- **License**: SIL Open Font License 1.1 (OFL-1.1).
  Repository historically shipped under Apache-2.0 and the OFL relicensing
  retains a notice for the earlier release — both licenses are jam-safe.
- **Upstream LICENSE (OFL)**: https://github.com/JetBrains/JetBrainsMono/blob/master/OFL.txt
- **Project page**: https://github.com/JetBrains/JetBrainsMono
- **Used for**: HUD monospace numbers (reserved via the `Mono` Label type
  variation in `assets/themes/default_theme.tres`).

---

## SIL OFL 1.1 — short summary

You can use, embed, modify and redistribute these fonts freely as long as
you (a) keep the OFL license file with any redistribution of the font
binaries or sources, and (b) do not sell the fonts by themselves (selling
them as part of a larger work, like a game, is fine). The OFL also asks
that derivative font files not reuse the original Reserved Font Name —
this game does not modify the font binaries, so no rename is required.

Full text: https://openfontlicense.org/open-font-license-official-text/
