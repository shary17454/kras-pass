# Duel Combat Revision 3: تسليم المراجعة

الحالة: prototype مختبر؛ لا commit/push/merge من العامل. هذه وثيقة تسليم وليست قبول balance أو READY أو native. خطة القياس 270 لم تبدأ.

## العقد

- بعد `Fighter.setup` وتهيئة الصحة الحقيقية إلى `max_health`، يفعّل MatchScene الملف فقط لـ`duel_pit` مع combat revision 3 الحالي؛ revisions 0/1/2 وبقية الألعاب تبقى خارج الملف. يعاد التفعيل في spawn/rebuild، ولا يعيد تطبيق الملف ضبط الصحة أو الحالة القتالية.
- من قيم power/resist الأساسية بعد perks، وبمرجعيهما المحايدين: `B=(P/P0)*(R/R0)^3`، ثم `f=(clamp(B,0.85,1.15)/B)^0.25`؛ يصبح `P'=P*f` و`R'=R*f`. إعادة التطبيق تبدأ من القيم الأساسية، لا القيم المقيسة سابقًا؛ لا تغيير معاملات AI أو stats العامة.
- `COMBAT_REVISION=3` و`VERSION=6` دون تغيير binary schema. تسجل/تطبق `duel_damage` بعد respawns/world/bounds وقبل evaluate_end؛ يتجاهلها dispatch السابق للـworld. حدث واحد لكل keyframe، حقول kind/damage فقط، دون stocks مصطنعة.
- load guards تتحقق من Duel/revision، tick canonical موجب وداخل التسجيل ومتوافق مع keyframe، التفرد/الاكتمال، عدد damage مطابق للاعبين وقيم finite ضمن الحدود. حد events العام 30000 و4MiB في القراءة والالتقاط؛ legacy/input-only يحتفظان بعقدهما.

## الأدلة والحدود

جميع الروابط التالية أدلة محلية قائمة خارج Git تحت `qualification-quickplay-20261122/duel-compound-integrated`؛ لا تعتمد على raw files غير مدرجة في commit عبر relative subdirectory links. [Manifest الموجز](duel-compound-revision3-20261122.json) يثبت counts وSHA-256 ومسارات الأصول.

| الدليل | النتيجة |
|---|---|
| [RED01 الأصلي](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01/result.json) | 184 pass / 2 fail؛ اختلاف damage عند tick1800 وseek48؛ محفوظ دون overwrite |
| [GREEN02 الأصلي](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-02/result.json) | 1873 pass؛ المعايير الأصلية186 محفوظة +1687 channel-proof |
| [Full الأصلي](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/full-01/result-original.json) | 531084 assertions؛ 542.3s؛ exit0؛ guards0/0 |
| [Compile](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/compile-01/result.json) | 487 scripts؛ exit0؛ guards0/0؛ stable2745 |
| [Revision disk resave](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/replay-revisions-01/result.json) | 81 pass؛ يشمل actual disk resave revisions1/2 |

E2E ثابت seed117، roster Sakhra/Turs/Nabta/Ghaim، 4AI normal2، natural110s/guard180sim s، بلا powerups/suddenDeath أو حقن state/input/keyframes. record→disk→load→play/seek، أول contact31 وseek48→25→48. انتهت الجولة طبيعيًا عند2528tick؛ scores[2,15,2,2]، places[2,1,2,2]، stocks[0,1,0,0]، damage[0,17,0,0] والحياة[false,true,false,false] متطابقة. drift playback0.529297m/seek0.683754m تحت2m، desync=-1. القناة المحملة تساوي live.events؛ 421/421 damage events تطابق الحالات المرصودة، دون off-keyframe events. live113 hit events مقابل playback112: لا تعميم determinism أو تطابق contact sequence.

Full قاس2745 ملفًا منها525 tests، و60 sparse-absent S معلنة؛ قبل/بعد متطابقان، بما يشمل source/tests/assets/tools/native/server/config. SHA الشامل: `1bdea23254c097049ad40659d182a461160df986c70451a1fe58bd111afb1f1d`. بصمة simulation: `65aa9aa6ca22c34061834839a9ca09a498ca68c790f31d6ae65bbea4c9634aa4`.

القبول مقيد بـ[السياسة المعلنة قبل التشغيل](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/full-01/expected-fault-policy.json) و[التدقيق الأصلي](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/full-01/fault-audit-original.json): Save84 مرة، Router17/25/36 ثلاث مرات، ومسبارا inner-zero-assert من balance_sim115–123 فقط؛ تطابق SHA/stack/suite boundaries/counts في السجلين، unmatchedErrors=0. الأصول لم تعد تصنف أو تستبدل بعد التشغيل. العملية terminal ولا Godot متبقٍ للعامل؛ لم يتغير production/tests أثناء التشغيل.

تبقى [وثيقة RED](duel-compound-replay-e2e-2026-11-22.md) و[وثيقة E2E02](duel-compound-replay-e2e-02-2026-11-22.md) دون تعديل كسجلين تاريخيين، لا كحالة full الحالية. مراجعة واختيار ملفات commit مسؤولية parent.
