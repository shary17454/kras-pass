# Duel revision3 E2E02: first post-fix run PASS

`duel-e2e-117-02`: **1873 assertions passed**، Godot exit0، stdout/engine guards0/0، engineErrors=false، timedOut=false. انتهت العملية ولا Godot باقٍ لهذا العامل. لا production edits/full/commit/push أو قياس إضافي.

نفس الحالة المعلنة: seed117، sakhra/turs/nabta/ghaim، أربعة AI normal2، النافذة الطبيعية110s وguard180sim s، بلا powerups/suddenDeath أو حقن positions/health/inputs/keyframes. انتهت الجولة طبيعيًا عند2528tick /42.133333s؛ live سجل113 hit events و84 swings، وplayback112 hit events. لا ادعاء بتطابق contact sequence أو determinism عامًا.

## القناة الفعلية من الملف

- حُفظت نسخة `_world_events.duplicate(true)` في out الخاص بـlive قبل teardown، ثم حُذفت القناة الكبيرة من public report واستُخدمت counts فقط.
- `replay.events == live.world_events` نجحت بعد تحميل الملف الفعلي من القرص.
- **421 keyframe =421 duel_damage event**، حدث واحد فقط لكل keyframe، بالحقول الدقيقة kind/damage فقط؛ لا stocks مزيفة في القناة.
- **421/421** event.damage طابقت `live.states[tick].damage` لجميع ticks الملتقطة، بلا فلتر sample أو phase؛ off-keyframe count=0.
- المعايير الأصلية186 لم تُعدّل. بعد تجريد إضافات proof/report عاد ملف الاختبار حرفيًا إلى SHA-256 الخاص بـRED01؛ أضاف proof1687 assertion فقط. النتيجة1873=186+1687.

## تطابق المقارنات القديمة

| النقطة | damage في live وplayback/seek |
|---|---|
| tick1800 | [0,68,57,13] |
| seek48→25→48 بعد أول contact عند31 | [4,0,0,9] عند48؛ rewind عند25 بلا damage |
| terminal2528 | [0,17,0,0] |

النتائج النهائية متطابقة: scores[2,15,2,2]، places[2,1,2,2]، stocks[0,1,0,0]، ctx/Fighter liveness[false,true,false,false]، والصحة كلها100. Profile مفعّل ومعاير بعد spawn وbackward rebuild. عُزل root/cache/dirty/readOnly/index/settings واستُعيدت كلها.

Playback drift=0.529297m، seek drift=0.683754m، تحت حد2m المعلن دون تخفيف؛ desync=-1 لكليهما.

## الأدلة المحلية والثبات

Parent wrapper أكد stable=true على2744 ملفًا قبل/بعد. Simulation fingerprint:
`65aa9aa6ca22c34061834839a9ca09a498ca68c790f31d6ae65bbea4c9634aa4`

الاختبار المنفذ SHA-256:
`74f76e556c8d1b22bbfe4ad5233ba702e30385632907dac61db08e75038ff6e3`

الأدلة محلية خارج source Git تحت qualification-quickplay-20261122/duel-compound-integrated:

- [result02 الأصلي](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-02/result.json)
- [stdout02: counts والمشاهدات الأصلية](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-02/stdout.log)
- [source-before02](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-02/source-before.json) و[source-after02](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-02/source-after.json).
- [RED01 محفوظ دون overwrite](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01/result.json):184 pass/2 fail.

التسجيل02 وduel-e2e-observations.json تحت save/duel_revision3_e2e_8e44a96da973db36c1ca7d954c324188. SHA-256 لملف replay الفعلي:
`c164541eb0bbc96f087502ba8c11b4e9a4193cbd43bc558d5dd3fc82d3cee7a5`

حالة handoff: هذه الحالة الثابتة PASS بعد إصلاح الأب؛ لا full أو قبول إصدار أو تعميم determinism.
