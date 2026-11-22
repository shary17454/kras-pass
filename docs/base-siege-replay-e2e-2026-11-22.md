# BaseSiege revision 2: Replay E2E

## الحالة

**121 assertion ناجحة من أول تشغيل للحالة الثابتة**؛ خروج Godot0 وstdout/engine guards0/0. نجح compile اللاحق لـ483 سكربتًا، ثم اكتملت full suite بـ525685 assertion على المصدر نفسه. لا process باقية. ثُبّت الكود والاختبارات لاحقًا في `c95b84030ab6587465d6fbee1353d00fbeb0b73f` دون دمج إلى main أو نشر إصدار.

[ملخص الحالة وexpected-fault closure](base-siege-atomic-2026-11-22.md) و[manifest counts/hashes](base-siege-verification-2026-11-22.json).

## الحالة المعلنة قبل التشغيل

Seed117، أربعة AI بمستوى2، roster nabta/sakhra/fanoos/ramla، iron_flats الأصلية، جولة واحدة بنافذة105s وduration_override=0. بلا powerups أو sudden death؛ هذه الإعدادات نفسها مسجلة في config. Guard لكل live/playback هو180 ثانية محاكاة.

بُني المشهد من spawns وصحة100 الحقيقية. لا تعيين لمواضع أو صحة أو input packets أو keyframes مصطنعة. التسجيل تلقائي عبر MatchScene واكتمال الجولة وReplays.save؛ ثم تحميل الملف الحقيقي عبر Replays.load_replay. فُحصت مطابقة قناة keyframes المحملة بايتًا ببايت مع التسجيل.

## النتيجة الفعلية

انتهت الجولة طبيعيًا عند **tick1193 / 19.883333s** قبل سقفها، مع **25 base_hits و3 bases_broken** في live وفي playback.

| الحالة | live وplayback |
|---|---|
| scores | [0,0,29,14] |
| places | [3,3,1,2] |
| ctx/Fighter liveness | [false,false,true,false] |
| صحة القواعد | [0,0,100,0] |
| hits لكل قاعدة | [8,8,0,9] |
| desync | -1 |
| maximum playback drift | 0.626117m |

ملف القرص:1193 input ticks و198 keyframe و39 checkpoint. قاعدة نقطة المقارنة المعلنة `min(1800, recorded tick count)` اختارت1193؛ تطابقت scores/places والحياة وصحة القواعد وhits وcooldowns وvisibility وcollision layers.

## Seek والعزل

أول ضرر حقيقي عند tick159. نفّذ pb_seek الحقيقي174 ثم153 ثم174: قبل الضرر الصحة كلها100 والنقاط صفر؛ بعده صحة[87,100,100,100] وhits[1,0,0,0] ونقاط[0,0,0,1]. تطابقت المشاهدات مع live والتشغيل المتصل ومع تكرار seek، دون تطبيق إصابة مرتين.

Seek desync=-1، وmaximum drift=0.266727m. حد drift المعلن مسبقًا أقل من2m في التشغيل والـseek؛ لم تُغير البذرة أو تُخفف assertions.

عُزل root/cache/dirty/read-only paths وReplays index في مجلد فريد، وأُعيدت مع enabled/batch depth/autosave وUserSettings وAudioManager وDevTools. بقي التسجيل للفحص دون حذف fixtures خارج المجلد المعزول.

هذه حالة E2E تتضمن تدمير قواعد فعليًا، لكنها لا تعمم determinism على كل البذور ولا تثبت وحدها fatal trade متزامنًا؛ اختبار atomic fatal المنفصل باقٍ.

## الأدلة المحلية

الجذر المحلي ignored:
`/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence`

- [نتيجة E2E](/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence/replay-e2e-117-01/result.json)
- [stdout ومشاهداته الأصلية](/private/tmp/kras-base-siege-fix-20261122/.godot/base-siege-atomic-evidence/replay-e2e-117-01/stdout.log)
- [اختبار E2E](../tests/suites/test_base_siege_replay_e2e.gd)

SHA-256 للتسجيل الفعلي:
`b7f54a76d77425a51fe5efe37b6ddf50e06bb8c290943045f3e161287103ffa9`.

Manifest المختار مع docs يحدد مسار replay الأصلي تحت save الفريد. Raw logs/saves/snapshots ليست مطلوبة داخل commit؛ لم يُعمل لها stage.
