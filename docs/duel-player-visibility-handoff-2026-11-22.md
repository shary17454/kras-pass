# تسليم وضوح Duel للمراجعة

## ملحق العقود الدائمة Portable، الحالة الأحدث

استُبدل تدقيق Node التاريخي الذي قيّد HEAD/branch والتطابق الشامل للمشروع بانحدار دائم بلا Git أو history. يقرأ `tests/contracts/duel_visibility_contract.mjs` وfixture `tests/fixtures/duel_visibility_baseline.json` ببصمات12 دالة أصلية متحققة؛ يحمي الدوال الهندسية/التأطير المقصودة وعقود fade/material/physics فقط، ولا يمنع ميزات أخرى في بقية المشروع.

نجح Node6/6 داخل الشجرة وفي snapshot معزول بلا `.git` ومع Git غير متاح عبر PATH. خمس snapshots سلبية للهندسة والتصادم وموضع physics وحارسه وميزانية الأشعة خرجت1 عمدًا عند العقد المقصود. لا blanket skip، ولا تغيير إنتاجي أو GDScript في هذا الملحق، ولا تشغيل Godot أو commit/push.

[التدقيق التاريخي وأدلته ونتائج النقل والسلبيات](/Users/shrybnhshymbnmrzwqbnhwyd/Documents/Codex/2026-08-14/new-chat/qualification-quickplay-20261122/duel-visibility-portable-contract-20261122/README.md) محفوظة خارج Git. فقرة allowlist أدناه توثق المرحلة السابقة فقط؛ ليست السياسة الدائمة الحالية. بصمات GPU التاريخية لم تُستبدل أو تُنسب إلى hashes اختبارات Node الجديدة.

## ملحق تسجيل الحزمة بعد مراجعة parent

أُغلقت فجوة عدم دخول الحزمة في full/CI: سُجّلت `test_duel_visibility.gd` مرة واحدة في `tests/test_runner.gd`. ينشئ `run()` الآن PhysicsHost child فقط إذا لم يوفّر host الأصلي `run_in_physics`؛ تمر الحالات على المضيف المناسب ثم تُحذف عقدة الـadapter مع انتظار process frame. المشغّل المستقل يستخدم مضيفه القائم ولا ينشئ adapter إضافيًا.

عُدّل allowlist فحص المصدر ليسمح **بسطر التسجيل المحدد وحده** في runner: بعد إزالة ذلك السطر يجب أن يطابق الملف الأصل حرفيًا. لم يُضف أي إعفاء إنتاجي. بقية فحوص Node الستة بقيت ناجحة، و`git diff --check` ناجح.

- [main-focused عبر `--suite=duel_visibility`](/private/tmp/kras-duel-visibility-evidence-20261122/main-unit-01-adapter/result.json): **385 assertions**، exit0، source stable، stdout/engine guards0.
- [standalone بعده](/private/tmp/kras-duel-visibility-evidence-20261122/unit-07-adapter/result.json): **385 assertions**، **51 عقدة قبل/51 بعد**، exit0، source stable، stdout/engine guards0.
- [بيان الفروق والبصمات الجديد](/private/tmp/kras-duel-visibility-evidence-20261122/handoff/test-registration-followup.json): الفروق منذ GPU في أربعة ملفات اختبارات فقط: suite وmain runner وعقد Node وwrapper الذي يضيف مدخل `main-tests`. **لا فروق إنتاجية منذ GPU**.

تم التشغيل بالتتابع فقط بعد الإذن المشروط وفحص انتهاء Faraday، وانتهت العمليتان terminal ثم حُرر slot. لا full أو commit/push. أدلة GPU أدناه تبقى ببصمات وقت التقاطها؛ لا يُعاد نسب snapshot الاختبارات الجديد حرفيًا إلى التصوير السابق. `qualification.json` التاريخي محفوظ دون overwrite، وهذا الملحق يثبت تغييرات الاختبارات اللاحقة.

الحالة: مرشح غير committed في `/private/tmp/kras-duel-visibility-20261122`، فرع `fix/duel-player-visibility-20261122`، الأصل `ff0f9aaa6b2d5bb0c8dd91508fc28fbb3bc443c7`. لا commit/push/merge ولا full suite أو Apple/production. جميع عمليات Godot الخاصة بهذا العمل terminal، وحصرية native GUI محررة.

## الملفات والعقد

- [ArenaCamera](../src/camera/arena_camera.gd): التأطير وحماية تصادم الكاميرا كما في الأصل؛ أضيف فقط استدعاء المعالجة البصرية من `_physics_process`، مع استعادة المواد عند configure/exit.
- [arena_occlusion_fader.gd](../src/camera/arena_occlusion_fader.gd): world mask=1، عينتا جسم/رأس، أربعة أهداف كحد مسح، ست إصابات لكل شعاع، حتى48 query/عينة، وتيرة لا تتجاوز10Hz بلا catch-up. الكاش حتى64 مدخلًا، والنسخ عند cache miss فقط؛ exact material reference restore وإطلاق الموارد وWeakRefs مُختبرة.
- [Arena tagging](../src/arenas/arena.gd): وسم الـ24 ledge والـSummit فقط في الوصفة الأصلية، لا floor/rim ولا تعديل vertex أو collider أو transform أو spawn أو Node layout.
- opt-in عبر `ArenaDef.param("camera_occluder_alpha", ...)` وقت التشغيل: fallback=0.12 لـduel_pit وصفر للبقية؛ لم يتغير `ArenaDef` أو `data/arenas.json`. لمست هذه الإضافة JSON أثناء التحضير ثم أُزيلت قبل التنفيذ؛ تغيير بايتاته يغيّر `PartyPlaylist.catalog` وقوائم محفوظة ومفاتيح يومية، وهو غير مسموح لهذا الإصلاح البصري.
- يستخدم نسخة `StandardMaterial3D` مع `TRANSPARENCY_ALPHA` وalpha موجبة، **لا GeometryInstance3D.transparency**. لا تعديل للمواد المشتركة أو visibility/layers/collision/AI state أو قواعد/عشوائية أو حفظ/replay semantics.

بصمة simulation source الحالية: `fc445820e5a6bafcb4624f5aa1b7a40f9f8b408141e555de25d96cfa0a85b38b`. [qualification.json](/private/tmp/kras-duel-visibility-evidence-20261122/handoff/qualification.json) يثبت hashes الملفات المملوكة ويقارنها بجميع snapshots النهائية دون اختلاف؛ هذه بصمات مرشح لا commit جديد ولا تأهيل توازن.

## سلامة الفيزياء وsnapshot

المراجعة كشفت أن نسخة المرحلة الأولى استدعت `intersect_ray` من `_process`. الإعداد الفعلي المسجل هو `physics/3d/run_on_separate_thread=false`، المحرك `DEFAULT` و60Hz، لكن ذلك لا يجعل موضع الاستعلام عقدًا آمنًا. وفق [توثيق Godot للوصول إلى physics space](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html#accessing-space)، نُقلت الاستعلامات إلى `_physics_process` فقط، وأُضيف رفض صريح لأي استدعاء من idle قبل أي query. التأطير بقي في `_process` دون تعديل.

اختبار dispatch يعمل من physics callback حقيقي، لا بمجرد تغيير ProjectSettings بعد إنشاء الخادم. لم نشغّل الخادم بإعداد separate_thread=true، ولا نزعم تأهيل تلك التهيئة؛ تم إثبات إعداد المشروع الحقيقي وحماية موضع الوصول وفق العقد الموثق، دون تغيير إعدادات الفيزياء أو delta.

[snapshot AI/التصادم النهائي](/private/tmp/kras-duel-visibility-evidence-20261122/unit-06-final/save/duel-visibility-snapshot.json):

- `observations before == after == [false,false,true]`: هدفان محجوبان وهدف مكشوف ضابط، عبر AIBrain الحقيقي قبل/بعد fade موجبة alpha.
- `unchanged=true`: RID مصادم الشعاع نفسه، body/mesh/shape transforms، shape size/resource/disabled، collision layer/mask، موارد meshes، موضع target والكاميرا وحالة alive متطابقة. الملاحظات التُقطت داخل physics callback.
- SHA-256: `fd8ae61cddb1d6e0dc9879152b79ce91b626d7342cad279351b4deb5d5a761db`.

## الاختبارات الفعلية

- [اختبار GDScript المركز](../tests/suites/test_duel_visibility.gd) عبر [runner معزول](../tests/duel_visibility_runner.gd): **385 assertions**، exit0، stable source، stdout/engine guards0 في [unit-06-final](/private/tmp/kras-duel-visibility-evidence-20261122/unit-06-final/result.json).
- العقد **51 قبل/51 بعد**؛ التحقق يشمل الأصلي مقابل الموسوم، vertex arrays والتصادم/التحويلات، استعادة null override، عدم استبدال shaders غير معروفة، حد الكاش64 مع70 مرشحًا، إطلاق نسخ المواد وprune للعقد المحذوفة، وتكرار30 دورة fade/restore دون نسخ جديدة.
- [عقود المصدر Node](../tests/duel_visibility_source.test.mjs): **6/6**، تشمل مطابقة بايتات source/data/tests القديمة خارج ملفي العرض المعدلين، وبقاء بناء pit كما كان عدا tagging، وعدم وجود physics queries الجديدة في `_process`.
- [wrapper](../tests/run_duel_visibility.mjs) يسجل source/command/stdout/engine/terminal/guards ويمنع overwrite وتكرار عمليتنا. [physics host الاختباري](../tests/duel_visibility_physics_host.gd) لا يغيّر حراس الإنتاج.

## دليل GPU: ساكن وحَي منفصلان

المحرك الفعلي `4.7.1.stable.official.a13da4feb`، **Metal4.0 / Apple M5 (Apple9)** على Mac، مرة بـ`mobile` ومرة بـ`forward_plus`. لا spoofing ولا software fallback، ولا ادعاء iPhone.

| النطاق | الصور/النتيجة |
| --- | --- |
| [Mobile static](/private/tmp/kras-duel-visibility-evidence-20261122/mobile-03-final/save/screenshots) | 8 أزواج before/after، h1/h4 × ar/en × اتجاهين، نفس world/camera transforms، بعد انتهاء إعلان البداية طبيعيًا. |
| [Forward+ static](/private/tmp/kras-duel-visibility-evidence-20261122/forward-01-final/save/screenshots) | 8 أزواج بالنطاق نفسه؛ لا mask/silhouette بدل أجسام اللاعبين. |
| [Mobile h4 live](/private/tmp/kras-duel-visibility-evidence-20261122/live-mobile-h4-01/save/visual-report.json) و[h1 live](/private/tmp/kras-duel-visibility-evidence-20261122/live-mobile-h1-01/save/visual-report.json) | أربع صور، الاتجاهان لكل تكوين،3 ثوانٍ إضافية لعب فعلي لكل اتجاه. |
| [Forward+ h4 live](/private/tmp/kras-duel-visibility-evidence-20261122/live-forward-h4-01/save/visual-report.json) و[h1 live](/private/tmp/kras-duel-visibility-evidence-20261122/live-forward-h1-01/save/visual-report.json) | أربع صور بالنطاق الحي نفسه. |

المراقب [duel_visibility_live.gd](../tests/duel_visibility_live.gd) يرث مسار `stage_zero_visual` الموجود دون تعديل ملفه أو شروطه؛ وقت اللعبة تقدم إلى نحو106.5 من110، وجميع اللقطات8 تحقق phase حي و`paused=false / pause_menu_present=false / app_backgrounded=false` وأربعة أحياء. كل process/guard exit0 وsource hashes ثابتة. الـfixture الساكنة موسومة صراحة، ولا تُستخدم بديلًا لدليل live.

فُحصت جميع صور after الساكنة16 وصور live الثماني الأصلية بأداة `view_image`، مع before ممثل لـh1/h4 portrait في كل محرك. التحسن ظاهر: الجسم البرتقالي الذي حجبته ledge الأمامية، والبني/الأصفر، والجسم الأخضر تحت Summit تظهر أجسامهم في مواضع البداية وفي h4 live. **h1 portrait مع ثلاثة AI يظل متكدسًا في الوسط وتحد الأجسام/المؤثرات المتراكبة من القراءة؛ لا ادعاء أن كل مقاتل ظاهر بالكامل دائمًا**، ولا توسعة إلى تغيير هندسة/قواعد أو كشف شامل خلف اللاعبين.

أمثلة أصلية:

- Mobile h4 portrait: [before](/private/tmp/kras-duel-visibility-evidence-20261122/mobile-03-final/save/screenshots/h4-ar-portrait-before.png)، [after](/private/tmp/kras-duel-visibility-evidence-20261122/mobile-03-final/save/screenshots/h4-ar-portrait-after.png)، [live](/private/tmp/kras-duel-visibility-evidence-20261122/live-mobile-h4-01/save/screenshots/duel_pit-portrait.png).
- Forward+ h1 portrait: [before](/private/tmp/kras-duel-visibility-evidence-20261122/forward-01-final/save/screenshots/h1-ar-portrait-before.png)، [after](/private/tmp/kras-duel-visibility-evidence-20261122/forward-01-final/save/screenshots/h1-ar-portrait-after.png)، [حدود التكدس في live](/private/tmp/kras-duel-visibility-evidence-20261122/live-forward-h1-01/save/screenshots/duel_pit-portrait.png).

## الأداء وحدوده

| Mac live smoke | query max/sample | cache max | CPU fade sample p95/max، microseconds | node range أثناء اللعب |
| --- | --- | --- | --- | --- |
| Mobile h4 | 16 | 4 | 372 /509 | 613–613 |
| Mobile h1 | 19 | 9 | 478 /753 | 610–808 |
| Forward+ h4 | 16 | 4 | 372 /510 | 613–613 |
| Forward+ h1 | 18 | 9 | 461 /831 | 610–808 |

هذه عينات CPU قصيرة على **Mac**، لا frame time/GPU timing أو FPS/حرارة/بطارية iPhone. زيادة عقد h1 تشمل مؤثرات القتال الحية؛ وحدها لا تثبت leak، كما أن الاختبار القصير لا ينفي نموًا طويلًا. دليل تحرير fixtures المركز51/51 والسجلات الخالية من engine leaks منفصلان عن ذلك. حد48 query/عينة و64 cache مُثبتان باختبارات عدائية؛ لا نسخ material لكل frame.

## الفشل المحفوظ وما لم يُعتمد

- `import-01`: خطأ inference في نقطة الشعاع، engine exit0 لكن strict guards رفضاه؛ أصلح النوع ولم يُعامل كنجاح.
- `mobile-01`: التقاط تقني انتهى لكن بطاقة التعليمات حجبت الأجسام؛ ليس دليل وضوح صالحًا.
- `mobile-02-physics`: after أظهر التحسن لكن before احتوى إعلان البداية المتلاشي؛ احتُفظ به ولم يُعتمد pair نهائيًا.
- النسخة التي استعلمت من `_process` ليست النسخة النهائية. `unit-05-physics` ثم `unit-06-final` وعمليات native النهائية تخص التصحيح الفيزيائي.
- لا تعديل للـtouch labels الخاصة بـFeynman أو BaseSiege الخاص بـNoether؛ UID غير متتبعة لاختباري melee/replay ظهرت من import في الشجرة الخاصة وتظل ملفات مولدة، وليست تعديلًا مملوكًا مقترحًا لإنتاج هذين النظامين.
- المرشح للتسليم والمراجعة فقط؛ لم يُجرَ full أو تأهيل جهاز أو campaign توازن جديد. `releaseReady=false`. أي توسيع لتراكب المقاتلين أو أداء جهاز فعلي يتطلب نطاقًا/إذنًا ودليلًا منفصلين.
