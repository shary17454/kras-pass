# Bundled UI Fonts

Unmodified upstream font binaries from `google/fonts`, commit
`7085eb89a950e85db5b166b7a58d414544b4140c`.
Source: https://github.com/google/fonts/tree/7085eb89a950e85db5b166b7a58d414544b4140c/ofl

Each file retains its original SIL Open Font License 1.1 in the accompanying
`*-OFL.txt`. Local filenames omit the upstream variation-axis suffix only;
the binaries have not been altered or subsetted.

| Local File | Upstream Path | SHA-256 |
| --- | --- | --- |
| NotoSans.ttf | notosans/NotoSans[wdth,wght].ttf | bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d |
| NotoSansArabic.ttf | notosansarabic/NotoSansArabic[wdth,wght].ttf | 63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e |
| NotoSansSymbols.ttf | notosanssymbols/NotoSansSymbols[wght].ttf | f7e7e04b4a24b6c78893d50cbfd2b2f6cae49617ab047bfef668d252adb128f7 |
| NotoSansSymbols2.ttf | notosanssymbols2/NotoSansSymbols2-Regular.ttf | 7d5fb73b7ca67a6798101741f5d280a3d016a56a197afcd4199dbb57b4b82a21 |
| NotoEmoji.ttf | notoemoji/NotoEmoji[wght].ttf | de6c18832938afc99caf132b39d6a30a19bac7f2e812e28db2535b4608d27551 |

The UI uses variable weights 400 and 700 with explicit Latin, Arabic, symbols
and monochrome emoji fallbacks. Automatic operating-system fallback is disabled
on all ordinary faces. User-authored text outside their coverage uses the prior
operating-system font path separately, preserving its platform-dependent name
coverage without changing the ordinary shared fonts. Known UI glyphs must shape
from the bundled chain, verified by tests. Controls set their font before text;
this ordering alone did not reduce retained fallback memory in the headless
Label probe. A bundled project theme is also configured, but memory and layout
qualification remain separate from glyph coverage tests. No global TextServer
cache eviction is performed in live UI. Both export presets explicitly include
the original `*-OFL.txt` license files in the application pack.
