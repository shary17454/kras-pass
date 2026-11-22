# Duel revision3 E2E: first-run RED handoff

**184 assertions passed / 2 failed**؛ Godot exit1، signal=null، timedOut=false، engineErrors=false. Guard stdout/engine كلاهما1 بسبب فشل assertions الحقيقي. انتهت العملية ولا يوجد Godot باقٍ لهذا worktree. لا rerun أو seed hunting أو assertion weakening أو production edits/full/commit/push.

الحالة المعلنة قبل أول run: seed117، roster sakhra/turs/nabta/ghaim، أربعة AI normal2، arena الافتراضية، نافذة110s دون override، guard180sim s، بلا powerups أو sudden death. بُني المشهد من spawns وصحة100 الحقيقية، وسُجّلت inputs/keyframes تلقائيًا؛ لا حقن positions/health/inputs/keyframes. التغيير المملوك: test_duel_compound_replay_e2e.gd وسطر تسجيله في runner، وهذه الوثيقة فقط.

## الفشلان غير المخففين

| المقارنة | live | playback/seek |
|---|---|---|
| tick1800، damage slot2 (Nabta) | 51 | 47 في playback |
| seek بعد أول contact عند tick48، damage slot0 (Sakhra) | 4 | 0 في seek |

أول contact فعلي عند31؛ seek نفّذ48→25→48، وأعاد بناء profile revision3 الصحيح. تكرار forward seek متسق مع نفسه، لكنه لا يعيد damage=4 للـlive. التشغيل المتصل عند48 طابق live؛ الاختلاف المبكر يخص مسار seek.

## ما نجح فعليًا

- live أنهى الجولة طبيعيًا عند2199tick /36.65s قبل سقف110s؛ ملف القرص يحمل2199 input ticks و366 keyframe و73 checkpoint و322 action packet غير صفري. طابقت keyframes الملف قناة capture الأصلية بايتًا ببايت.
- 104 rival hit events و68 swings في live؛ 102 hit events و68 swings في playback. لوحظ damage فعلي، وprofile مفعّل ومعاير بالقيم المشتقة بعد perks لجميع الشخصيات، بما فيه backward rebuild.
- النتيجة النهائية في الحالتين: scores [2,16,2,1]، places [2,1,2,4]، stocks [0,1,0,0]، liveness [false,true,false,false]، terminal damage [0,38,0,0].
- playback drift=0.444431m وseek drift=0.683754m، كلاهما تحت الحد المعلن2m؛ desync=-1 لكليهما. هذا لا يكفي لإعلان E2E PASS مع اختلاف damage.
- استُعيد root/cache/dirty/readOnly/index/settings وsave/audio/debug flags. بقيت كل الملفات والتسجيل والمشاهدات محفوظة في root المعزول؛ لا حذف لfixtures خارجية.

## الثبات والأدلة المحلية

Wrapper الأب أكد stable=true على2742 ملفًا قبل/بعد. simulation fingerprint المجمد:
`99cd4567496d1d830b31aa479e11b869461f2daea7e9a16403e28fe7536d69e7`

SHA-256 للاختبار المنفذ:
`94d7b6fbede55b9d5d776ab1bd12e89764212a6afff023c338cd2cc91a7caaa6`

جذر الأدلة المحلي غير المقصود للتثبيت في Git:
`/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01`

- [result الأصلي](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01/result.json)
- [stdout ومشاهدات E2E](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01/stdout.log)
- [source-before](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01/source-before.json) و[source-after](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-compound-integrated/duel-e2e-117-01/source-after.json).

التسجيل وduel-e2e-observations.json تحت save/duel_revision3_e2e_2f76c5233e19f7c235435d500c2a816f. SHA-256 للتسجيل:
`b5b3b21b35807c80f254fc5bf5cc25b00f3c4b06ffc85d17f14056cf8000aa10`

ملاحظة ساكنة لا إثبات سببي كامل: ReplayData.encode_keyframe لا يحمل damage_percent أو stocks، وMatchScene._record_or_apply_keyframe يصحح position/velocity/alive/ctx.scores فقط؛ لذا desync=-1 وتصحيح المواضع لا يثبتان تطابق Duel damage. لم يُقارن هذا الاختبار بـrevision2، فلا يدّعي أن الفرق regression حصري للـprofile الجديد. بانتظار مراجعة الأب قبل أي تعديل أو قياس تالٍ.
