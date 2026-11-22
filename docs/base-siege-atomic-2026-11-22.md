# BaseSiege: تسليم المراجعة

## الحالة الحالية

Full suite اكتملت: **525685 assertion ناجحة خلال 263.0s**، وخروج Godot **0**، وguards بوضع tests **0/0**. انتهت العملية ولا توجد process باقية لهذا العامل. ثبّت المراجع الكود والاختبارات في `c95b84030ab6587465d6fbee1353d00fbeb0b73f` بعد التحقق من تطابق الملفات مع capture؛ لم يُدمج إلى main أو يُنشر إصدار.

العمل في `/private/tmp/kras-base-siege-fix-20261122`، فرع `fix/base-siege-simultaneous-20261122`، من `ff0f9aaa6b2d5bb0c8dd91508fc28fbb3bc443c7`. لم تُعدل شجرتا المقارنة أو frozen1c، والـRED القديم محفوظ.

## الإصلاح والتوافق

- hooks مشتركة `begin_action_batch/resolve_action_batch`، افتراضيًا pass للألعاب الأخرى.
- BaseSiege يجمع أوامر الإطار ويطبق آثار القواعد قبل الإلغاءات، دون إزالة حراس alive أو readiness/range/facing.
- revision 0: Fighter/BaseSiege القديمان؛ revision 1: simultaneous melee مع BaseSiege القديم؛ revision 2 والجديد: melee مع atomic BaseSiege. `VERSION=6` بقي دون تغيير schema.
- rams في revision 2 تجمع جميع contenders وتختار nearest ثم stable slot؛ legacy يحتفظ بأول eligible ctx slot. one-hit cooldown وrecoil للمختار فقط، وأولوية swing على ram محفوظة.
- لا تغيير لـFighter عن ff0 أو AI أو tuning أو formulas. swing=13، ram=9، cooldown=0.3 مع عمر الساعة الأصلي.

## الأدلة المنجزة

| البوابة | النتيجة |
|---|---|
| RED عبر MatchScene._tick_live على ff0 قبل patch | 960 pass / 33 fail، بلا أخطاء محرك |
| RED لملاحظة ram contenders قبل تصحيح return | 1349 pass / 16 fail، بلا أخطاء محرك |
| الفحوص المركزة قبل E2E | 3154 assertion وcompile 482 |
| E2E تسجيل/قرص/تحميل/تشغيل/seek، seed117 | 121 assertion؛ 25 hit و3 تدميرات فعلية |
| compile بعد إضافة E2E | 483 سكربتًا |
| full على المصدر نفسه | 525685 assertion، exit0 وguards0/0 |

حالة E2E ثابتة واحدة ناجحة، وليست تعميمًا لـdeterminism أو إثبات تبادل fatal متزامن بعينه في مباراة AI؛ لذلك يبقى فحص atomic fatal المعزول ضروريًا. [تفاصيل E2E](base-siege-replay-e2e-2026-11-22.md).

## ثبات المصدر

Capture قبل/بعد full شمل **1387 ملفًا، منها 515 تحت tests**، وليس simulation fingerprint فقط. خرائط SHA-256 تطابقت، ولم يتغير الكود أثناء التشغيل.

- بصمة الشجرة الشاملة قبل وبعد: `8d0a347fc6197d294f8dc479619183c05b0ea330b8bdf3351f2d7669d09623e9`.
- simulation fingerprint: `dd9919031675fadb5fa8b075e0cf3c56f312533bac6100fe7d658f1173fb809d`.
- النطاق يستثني .git/.godot/docs/build/exports وdependency caches؛ يشمل الكود والاختبارات والأصول والأدوات وnative/server/config.

## Expected Fault Review

**الأصل محفوظ دون تعديل:** `full-01/result.json` ما زال `green=false`، و`fault-audit.json` ما زال يسجل Router3 غير مصنفة. خرج wrapper بـ2؛ هذا ليس خروج Godot الذي كان0. السبب أن المصنّف الأولي عرف Save injection فقط، واعتمد lastTestContext الموروث حيث لا يوجد TEST_START داخل router suite.

Audit لاحق مستقل أغلق الحالات الأربع المتعمدة في كل سجل بمطابقة exact fault + stack + حدود suite + العدد، وعلى نفس ملفات الاختبار ذات البصمات الملتقطة:

- Save واحدة: `test_save.gd:_failed_write:84` يحجب test_profile.json.tmp عمدًا ثم يختبر retry.
- Router ثلاث: `test_router_recovery.gd:17/25/36` تستخدم FaultRouter الذي يعيد null عمدًا؛ suite هي screen transition recovery.
- سطرا zero-assertion من probe منفصل في `test_balance_sim.gd:115-123`، وليسا فشل outer harness.
- **unexpected مثبتة بعد المراجعة:0**. لا تصنيف عام أو إخفاء أخطاء، ولا إعادة full أو تغيير المصدر من أجل green.

الحالة المراجعة: **PASS_WITH_DOCUMENTED_EXPECTED_FAULT_INJECTIONS**، مع الاحتفاظ بنتيجة المصنّف الأصلية كما هي، وليس استبدالها.

## الوصول المحلي للأدلة

[Manifest موجز قابل للتثبيت مع docs](base-siege-verification-2026-11-22.json) يحفظ counts/hashes ومسارات الأصل.

جذر الأدلة الخام **محلي ignored، وليس جزءًا من ملفات Git المختارة**:
`/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence`

- [full الأصلي](/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence/full-01/result.json)
- [fault audit الأصلي](/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence/full-01/fault-audit.json)
- [audit اللاحق المستقل](/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence/full-01/post-run-fault-review.json)

تبقى raw logs/saves/source snapshots محلية وغير staged؛ الروابط أعلاه ليست روابط ملفات متوقعة داخل commit. البوابات المحلية ناجحة ضمن نطاقها، دون claim جاهزية إصدار أو اكتمال device/production qualification.
