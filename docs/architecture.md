# البنية الحالية لكراس باس

جرد المرحلة 0 بتاريخ 25 سبتمبر 2026. يصف الشيفرة الموجودة، وليس تصميمًا نظريًا أو إعلان اكتمال المراحل التالية.
المرجع: `main` عند `bc15d24` مع التعديلات المحلية القائمة. لا يُنشأ إطار ثانٍ موازٍ لمجرد مطابقة أسماء المديرين في الخطة.
أُدرج ذلك الجرد في `19217e2` على `main`. متابعة التثبيت موثقة في [سجل الاستكمال](stage0-followup-2026-09-25.md).

## حدود المشروع

- `project.godot` ومشهد `scenes/boot.tscn` يشغّلان `src/core/main.gd` ثم `SceneRouter`.
- واجهات التطبيق تُبنى برمجيًا من `src/ui/screens`؛ ليست 27 ملفات مشاهد مستقلة. المسجل 27 مسارًا بما فيها المباراة.
- 39 تعريف لعبة: 35 تحديًا في الاختيار العادي و4 مواجهات زعماء للمغامرة. 34 حلبة و8 شخصيات و22 أداة قوة.
- `data/*.json` مصدر التعريفات؛ `Balance` يقرأها و`Registry` يحولها إلى Resources مكتوبة الأنواع.
- معظم الأشكال تُنشأ عبر `MeshFactory`، مع أصول طبيعية مستوردة في `assets/natural` وشيدرات محلية. المصدر الثقيل للصنوبر داخل `.gdignore` متروك عمدًا؛ المستخدم فعليًا `pine_mobile.glb`.
- `native/apple` جسر Objective-C++ لـAuthenticationServices وKeychain. المحرك Godot، وليس Flutter أو تطبيق لعب SwiftUI.
- `server` خدمة حساب Apple اختيارية باستخدام Node وSQLite و`jose`؛ ليست خادم محاكاة للمباريات المحلية.
- `Net.online_available = false`. وجود عقد إدخال افتراضي وشاشة مستقبلية لا يعني وجود Online جاهز.

## مسار المباراة

```text
قائمة/بطولة/مغامرة/تدريب
  -> MatchConfig + PlayerConfig[]
  -> SceneRouter.start_match
  -> MatchScene
      -> MiniGameController + MatchContext
      -> Arena + Fighter[]
      -> AIBrain[] -> InputRouter -> InputFrame -> Fighter
      -> ArenaCamera + MatchHUD + TouchSource[]
      -> PowerUpSystem + MutatorSystem + HoverMachine
  -> MatchResult
      -> Stats / Progression / Achievements -> SaveSystem
      -> Results / TournamentSession / AdventureSession
      -> ReplayData -> Replays
```

`MatchScene.teardown()` يستدعي تنظيف المتحكم ويفرغ Pool ويحرر الإدخال ويوقف الصوت. توجد مسارات إلغاء وإعادة وإيقاف مستقلة، تختبرها حزم lifecycle/race_conditions/matches.

## مقابلة المسؤوليات المطلوبة بالموجود

| الاسم في الخطة | المسؤول الحالي | المطلوب قبل أي استخراج في المرحلة 1 |
|---|---|---|
| GameManager | `SceneRouter`، `MatchScene`، جلسات الأنماط | تعيين حدود الملكية، لا مدير شامل جديد |
| MinigameManager | `Registry` + `MiniGameValidator` + `MiniGameController` | تثبيت العقد والبيانات المطلوبة |
| PlayerManager | `PlayerConfig` + `PartyRoster` + إنشاء Fighters في المباراة | فصل الملف عن الحالة أثناء الجولة |
| InputManager | `InputRouter` + `InputFrame` + `TouchSource` | تثبيت عقد المصادر دون كسر اللمس الحالي |
| RoundManager | `MatchScene` + `MatchPhase` | استخراج تدريجي إن خفّض الاعتماد المتبادل |
| ScoreManager | `MatchContext` + `MiniGameController.compute_scores` | توحيد واجهة النقاط الخاصة دون نسخ الترتيب |
| ResultManager | `MatchResult` + شاشات النتائج والترتيب | الحفاظ على التعادل والتجميع واختباراتهما |
| CameraManager | `ArenaCamera` | جعل احتياجات الكاميرا بيانات لا معرفات ألعاب |
| AudioManager | Autoload بالاسم نفسه | بنك أصوات ومخزن16 صوتًا، قناتا موسيقى وواجهة |
| SaveManager | `SaveSystem` | عدم إدخال ملف حفظ موازٍ أو تغيير معرفات الملفات |

## Autoloads وترتيبها

الترتيب مطابق لـ`project.godot`. الجرد الآلي يتحقق من وجود المصدر والعقدة المنشأة لكل واحد.

| النظام | المصدر |
|---|---|
| Log | `src/core/logger.gd` |
| Balance | `src/core/balance.gd` |
| Loc | `src/localization/loc.gd` |
| SaveSystem | `src/save/save_system.gd` |
| AppleAccount | `src/net/apple_account.gd` |
| UserSettings | `src/settings/settings_service.gd` |
| EventBus | `src/core/event_bus.gd` |
| InputRouter | `src/input/input_router.gd` |
| Haptics | `src/input/haptic_director.gd` |
| AudioManager | `src/audio/audio_manager.gd` |
| Registry | `src/core/registry.gd` |
| Access | `src/progression/owner_key.gd` |
| Progression | `src/progression/progression_service.gd` |
| Stats | `src/progression/stats_service.gd` |
| Achievements | `src/progression/achievements_service.gd` |
| Net | `src/net/net_service.gd` |
| Pool | `src/core/object_pool.gd` |
| Platform | `src/core/platform_service.gd` |
| Replays | `src/replay/replay_store.gd` |
| SceneRouter | `src/core/scene_router.gd` |
| DevTools | `src/debug/dev_tools.gd` |

## عقد اللعبة ودورة حياتها

`MiniGameDef` يحتوي المعرف ومفاتيح الترجمة والفئة والعدد والمدة ونوع التحكم والخرائط والتسجيل وقواعد النهاية.
المتحكم يحدد AI والحركة والكاميرا والتسجيل والنهاية، ويرث افتراضات مشتركة من `MiniGameController`.

الدورة الحالية:

```text
LOADING -> INTRO -> INSTRUCTIONS -> COUNTDOWN -> PLAYING
PLAYING -> SUDDEN_DEATH عند التعادل المدعوم
PLAYING / SUDDEN_DEATH -> FINISH -> RESULTS
RESULTS -> REWARDS / NEXT_ROUND / DONE
NEXT_ROUND -> INSTRUCTIONS
teardown عند مغادرة المباراة
```

جدول `MatchPhase.LEGAL` يمنع الانتقالات غير القانونية. لا حاجة لإعادة تسمية الحالات الآن لتطابق PREPARE/ENDING؛ المقصود في المرحلة1 تثبيت المسؤوليات واختبارات العقد.
جميع التعريفات تستخدم هذا المسار بالفعل؛ المرحلة8 تعني نقل التفاصيل المتبقية على دفعات، لا إعادة كتابة39 لعبة من الصفر.

## الإدخال

- `InputMap`: `pause` و`debug_menu` و`ui_back`، إلى جانب مفاتيح Godot الافتراضية للواجهة.
- الحركة والهجوم ليستا ناقصتين من InputMap: يقرأ `InputRouter` أجهزة كل مقعد مباشرة، ويدعم KEYBOARD/PAD/VIRTUAL/TOUCH/NONE.
- `InputFrame`: اتجاه الحركة والتصويب وبتات JUMP/ATTACK/ACTION/DASH/ABILITY وحالة الإطار السابق.9 بايت لكل لاعب في Replay.
- AI وإعادة المباراة يغذيان مصدرًا افتراضيًا؛ هذا عقد محلي وليس نقل شبكة فعليًا.
- تخصيص اللمس منفصل حسب الاتجاه وControlProfile. اللمس الرباعي له مناطق محمية، ولا يستخدم مواضع اللاعب الواحد الحرة.

## الشخصيات

المعرفات المحفوظة: `nabta`, `sakhra`, `fanoos`, `ramla`, `barq`, `mowja`, `ghaim`, `turs`.
لكل شخصية ست خصائص قائمة، تشمل التسارع، ومجموعها3.0. لا نحذف التسارع أو نعيد تسمية الشخصيات المحفوظة أثناء الجرد.
الميزات السلبية محدودة بمعاملات0.90–1.08. تطابق مجموع الأرقام ليس دليلًا على تكافؤ الفوز.
الألوان التجميلية تنسخ العرض فقط ولا تغير الخصائص. ملف الجرد يحفظ جدول الخصائص كاملًا.

## الحفظ وإعادة المباراة

- Schema للحفظ2، وترقية0/1 إلى2 موجودة مع نقل التقدم إلى ملفات محلية.
- وجود Schema أحدث في الأصل أو النسخة الاحتياطية يمنع الكتابة والحذف لكليهما؛ تبقى جلسة مؤقتة مع تنبيه مترجم. لا تُفسر بيانات إصدار غير مدعوم بمنطق الإصدار القديم.
- `profile.json` متعدد الملفات مع فروع مشتركة؛ `settings.json` مستقل. `.tmp` ثم `.bak` ثم تبديل الملف، وchecksum لاكتشاف التلف، لا لمنع الغش.
- `begin_batch/end_batch` يجمع حفظ تقدم المشاركين. إيصالات الأحداث تمنع احتساب نفس نتيجة البطولة مرتين.
- البطولة تستأنف بين الجولات، لا من منتصف فيزياء الجولة.
- Replay أصبحv5 لحفظ Mutators وChaos والفرق. v4 يحتفظ بالإطارات؛ v1–v3 لا يمكن تفسير مدخلاتها كصيغةv4 الجديدة وتبقى غير قابلة لإعادة دقيقة.
- التسجيل هجين: مدخلات60Hz وحالة موضع/سرعة10Hz وأحداث. ليس محاكاة حتمية ولا أساسًا معتمدًا لـNetcode.
- الحد الحالي أربع دقائق. عند تجاوزه يُلغى حفظ تلك المباراة وتُفرغ كل قنوات التسجيل؛ لا تُخزّن إعادة ناقصة على أنها كاملة. تمديد التسجيل يحتاج مرحلة33 وميزانية ذاكرة صريحة.
- `--test-data-dir` يعزل الحفظ والتسجيل في اختبارات المحرر؛ لا حاجة لتغيير HOME.

## التكرار والارتباطات المهمة

| الموضع | الملاحظة | القرار |
|---|---|---|
| Registry.validate وMiniGameValidator | تحقق متداخل للخرائط والنصوص والمدة | توحيد مصدر القواعد في مرحلة1 مع إبقاء اختبارات التغطية |
| Progression.world_progress/completion وProfileMetrics | حسابات متقاربة للملف النشط وأي ملف | اختبار تطابق قبل استخراج الدوال، لا تعديل حساب النجوم الآن |
| MatchHUD | استثناءات بمعرف goal_guard/tank_arena وقراءة controller.charges مباشرة | عقد بياناتHUD في مرحلة7 |
| AIBrain والـBrains الفرعية | وصول إلى MatchContext وإجابات المتحكم عبر call/get | طبقة Perception مقيدة في مرحلتي24–25؛ التأخير وحده لا يضمن العدالة |
| Fighter | عدة Locomotion modes في جسم مشترك | الاستخراج حسب العائلة في مرحلة5، لا نسخ جسم لكل لعبة |
| اشتقاقات الألعاب | fawda من ring، الكرة من goal_guard، rocket من kart، tank من turret | إعادة استخدام حقيقية يجب الحفاظ عليها أثناء النقل |
| Stats.record_powerup | لا مستدعٍ إنتاجي مباشر في البحث الحالي | مرشح حذف لاحقًا بعد مراجعة الاستدعاء الديناميكي؛ لم يُحذف |
| Net وشاشات المستقبل | بنية غير مفعلة وليست خطأ تحميل | لا تحويلها إلى Online في V1 ولا حذف تلقائي |

لا يوجد دليل يكفي لحذف أصل أو متحكم لمجرد غيابه من بحث نصي؛ الموارد قد تُختار من JSON أو بالوراثة أو أثناء التصدير.

## البناء والنشر

`tools/check_party.sh` يجمع فحص التجميع والجرد والاختبارات وانحدار السباق مع ملفات معزولة. الجرد لا يغطي بناء C++ أو توقيعiOS.
`tools/build_apple_bridge.sh` و`tools/export_ios.sh` يجهزان جسرApple والتصدير. ملفات البناء المولدة ليست مصدرًا بديلًا للعبة.
`ci_scripts` يعيد تجميع أرشيفات المكتبات ويتحقق منSHA256؛ ليس بوابة اختبار Godot كاملة. يلزم ربط الفحوص فيCI قبل أي Merge واسع.
أضيف إعداد `Game Quality` المستقل: استيراد ثم تجميع وجرد واختبارات وانحدار سباق و117 دورة مباراة. يتحقق من SHA256 للمحرك، دون مفاتيح نشر، ويحتفظ بالسجلات. نجاحه على GitHub وإلزامه لحماية الفرع لم يُثبتا بعد.
`railway.json` يبني Dockerfile ويستخدم `/health`. لم يُفحص النشر الحي أو تُغيّر أسراره في مرحلة0.

المرجع التنفيذي: [تقرير المرحلة0](stage0-audit-2026-09-25.md)، [جرد الألعاب](stage0-minigames.md)، [بوابات المراحل](development-stages.md).
