# جرد الألعاب المصغرة في المرحلة 0

لقطة بتاريخ 25 سبتمبر 2026، من أداة `tools/party_content_audit.gd`. لا تمثل اعتماد إصدار.

39 تعريفًا:35 لعبة عادية و4 زعماء.32 `NEEDS_POLISH` و7 `NEEDS_BALANCE` و0 `READY` و0 `REWORK` و0 `BROKEN`.

## معايير التصنيف

- `BROKEN`: تعريف أو متحكم أو AI أو خريطة أو ترجمة مطلوبة غير صالح في الفحص الهيكلي.
- `REWORK`: خلل شديد في المحاكاة وفق تقريرها؛ إعادة تصميم اللعب تتطلب قرار مراجعة أيضًا، لا مجرد هذا التصنيف الآلي.
- `NEEDS_BALANCE`: مؤشر توازن محفوظ يحتاج إعادة تحقق بعينة ممثلة، وليس حكمًا إحصائيًا نهائيًا.
- `NEEDS_POLISH`: اجتياز البوابات الآلية المحددة، مع بقاء مراجعة وضوح اللعب والتصميم والأجهزة. لا يعني أن كل التفاصيل صحيحة.
- `READY`: لا تمنحه الأداة تلقائيًا. يحتاج إغلاق الاختبارات وQA والتوازن والأداء على الأجهزة المدعومة.

## الدليل المشترك وحدوده

التجميع والتحقق الهيكلي يشملان39. `test_matches._every_minigame` يشغّل الأربعةAI على الخريطة الأولى ويختبر وجود نتيجة وترتيب وحركة ونهاية؛ أغلب جولات هذا الفحص مختصرة إلى5 ثوانٍ. لا يساوي ذلك لعب كل خريطة وكل عدد لاعبين بمدتها الطبيعية.

`tests/stage_zero_visual.tscn` يرسم كل تعريف في الخريطة الافتراضية بالعربية، لاعب بشري وثلاثةAI، أفقيًا وعموديًا. اختباره للتحميل وعدد اللاعبين وعدم فراغ الصورة، وليس حكمًا على جمالها أو سهولة التحكم.

مصدر مؤشرات التوازن: `build/balance/report.json` وعينتا إعادة سباق الصواريخ والجواهر في `build/party/`. العينات السابقة8 مباريات لكل لعبة، لا ألف مباراة جديدة في هذه الدورة. الزعماء الأربعة لا يشملهم التقرير الإحصائي.

المتحكم وAI والخرائط ونوع التحكم في كل صف روابط إلى التنفيذ الفعلي. JSON التفصيلي، بما فيه سلسلة الوراثة وقياسات العينة ومصدرها، يولد في `build/party/content-audit.json`.

## التقرير لكل لعبة

| اللعبة | الحالة | المتحكم | AI | التحكم | الخرائط | سبب إضافي أو نطاق متبقٍ |
|---|---|---|---|---|---|---|
| تحدي دبابات البر (`tank_arena`) | NEEDS_POLISH | [tank_arena](../src/minigames/tank_arena.gd) | [tank_brain](../src/ai/brains/tank_brain.gd) | `atv` | `tank_foundry`، `tank_oasis`، `tank_frost` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| زحام الحلقة (`ring_rumble`) | NEEDS_BALANCE | [ring_rumble](../src/minigames/ring_rumble.gd) | [generic_brain](../src/ai/brains/generic_brain.gd) | `movement_action` | `vortex_ring`، `storm_ring` | الخبير لا يتفوق على السهل في العينة السابقة |
| الساحة المنهارة (`crumble_court`) | NEEDS_POLISH | [crumble_court](../src/minigames/crumble_court.gd) | [platform_brain](../src/ai/brains/platform_brain.gd) | `movement_action` | `crumble_court` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| وعاء المصدّات (`bumper_bowl`) | NEEDS_POLISH | [bumper_bowl](../src/minigames/bumper_bowl.gd) | [generic_brain](../src/ai/brains/generic_brain.gd) | `movement_action` | `bumper_bowl` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| الفوضى (`fawda`) | NEEDS_BALANCE | [fawda](../src/minigames/fawda.gd) | [bomber_brain](../src/ai/brains/bomber_brain.gd) | `movement_action` | `vortex_ring`، `storm_ring` | الخبير لا يتفوق على السهل في العينة السابقة |
| حارس المرمى (`goal_guard`) | NEEDS_POLISH | [goal_guard](../src/minigames/goal_guard.gd) | [keeper_brain](../src/ai/brains/keeper_brain.gd) | `keeper` | `quad_court` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المغناطيس (`magnet_court`) | NEEDS_POLISH | [magnet_court](../src/minigames/magnet_court.gd) | [magnet_keeper_brain](../src/ai/brains/magnet_keeper_brain.gd) | `aim_and_move` | `quad_court` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| قلب العاصفة (`storm_heart`) | NEEDS_POLISH | [storm_heart](../src/minigames/storm_heart.gd) | [storm_keeper_brain](../src/ai/brains/storm_keeper_brain.gd) | `aim_and_move` | `quad_court` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المنصة الطائرة (`sky_court`) | NEEDS_POLISH | [sky_court](../src/minigames/sky_court.gd) | [keeper_brain](../src/ai/brains/keeper_brain.gd) | `aim_and_move` | `quad_court` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| الكرة المتفجّرة (`blast_ball`) | NEEDS_POLISH | [blast_ball](../src/minigames/blast_ball.gd) | [ball_brain](../src/ai/brains/ball_brain.gd) | `movement_action` | `ember_pit` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| عربات الخردة (`scrap_karts`) | NEEDS_BALANCE | [scrap_karts](../src/minigames/scrap_karts.gd) | [driver_brain](../src/ai/brains/driver_brain.gd) | `steering` | `scrap_yard` | الخبير لا يتفوق على السهل في العينة السابقة |
| نزال المدافع (`turret_duel`) | NEEDS_POLISH | [turret_duel](../src/minigames/turret_duel.gd) | [gunner_brain](../src/ai/brains/gunner_brain.gd) | `steering` | `iron_flats` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| خطف الجواهر (`gem_grab`) | NEEDS_POLISH | [gem_grab](../src/minigames/gem_grab.gd) | [collector_brain](../src/ai/brains/collector_brain.gd) | `movement_action` | `gem_hollow`، `glass_terrace` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| اندفاع النجوم (`star_rush`) | NEEDS_POLISH | [star_rush](../src/minigames/star_rush.gd) | [courier_brain](../src/ai/brains/courier_brain.gd) | `movement_action` | `star_meadow` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| شبكة الألوان (`paint_grid`) | NEEDS_POLISH | [paint_grid](../src/minigames/paint_grid.gd) | [painter_brain](../src/ai/brains/painter_brain.gd) | `movement_action` | `paint_grid` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المناطق (`mnatiq`) | NEEDS_POLISH | [mnatiq](../src/minigames/mnatiq.gd) | [painter_brain](../src/ai/brains/painter_brain.gd) | `movement_action` | `paint_grid` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المخرب (`mukharrib`) | NEEDS_POLISH | [mukharrib](../src/minigames/mukharrib.gd) | [saboteur_painter_brain](../src/ai/brains/saboteur_painter_brain.gd) | `movement_action` | `paint_grid` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| احتلال المنطقة (`zone_hold`) | NEEDS_BALANCE | [zone_hold](../src/minigames/zone_hold.gd) | [zone_brain](../src/ai/brains/zone_brain.gd) | `movement_action` | `dune_ring` | الخبير لا يتفوق على السهل في العينة السابقة |
| تحطيم الصناديق (`crate_smash`) | NEEDS_POLISH | [crate_smash](../src/minigames/crate_smash.gd) | [smasher_brain](../src/ai/brains/smasher_brain.gd) | `movement_action` | `crate_yard` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المختبر (`lab_crates`) | NEEDS_POLISH | [lab_crates](../src/minigames/lab_crates.gd) | [smasher_brain](../src/ai/brains/smasher_brain.gd) | `movement_action` | `crate_yard` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| تناوب الصناديق (`crate_relay`) | NEEDS_POLISH | [crate_relay](../src/minigames/crate_relay.gd) | [courier_brain](../src/ai/brains/courier_brain.gd) | `movement_action` | `relay_docks` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| سباق الحواجز (`hurdle_dash`) | NEEDS_BALANCE | [hurdle_dash](../src/minigames/hurdle_dash.gd) | [runner_brain](../src/ai/brains/runner_brain.gd) | `movement_action` | `hurdle_track` | مؤشر أفضلية مقعد البداية |
| سباق العربات (`kart_sprint`) | NEEDS_POLISH | [kart_sprint](../src/minigames/kart_sprint.gd) | [racer_brain](../src/ai/brains/racer_brain.gd) | `steering` | `circuit_loop` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| قف على اللون (`color_stand`) | NEEDS_POLISH | [color_stand](../src/minigames/color_stand.gd) | [color_brain](../src/ai/brains/color_brain.gd) | `memory` | `color_floor` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| صدى الرموز (`symbol_echo`) | NEEDS_POLISH | [symbol_echo](../src/minigames/symbol_echo.gd) | [echo_brain](../src/ai/brains/echo_brain.gd) | `memory` | `echo_hall` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| أسرع يد (`quick_draw`) | NEEDS_POLISH | [quick_draw](../src/minigames/quick_draw.gd) | [draw_brain](../src/ai/brains/draw_brain.gd) | `reaction` | `draw_stage` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المدّ الصاعد (`rising_tide`) | NEEDS_POLISH | [rising_tide](../src/minigames/rising_tide.gd) | [climber_brain](../src/ai/brains/climber_brain.gd) | `movement_action` | `tide_spire` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| عاصفة الأذرع (`sweeper_storm`) | NEEDS_POLISH | [sweeper_storm](../src/minigames/sweeper_storm.gd) | [dodger_brain](../src/ai/brains/dodger_brain.gd) | `movement_action` | `sweeper_ring` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| حفرة النزال (`duel_pit`) | NEEDS_POLISH | [duel_pit](../src/minigames/duel_pit.gd) | [duellist_brain](../src/ai/brains/duellist_brain.gd) | `dual_action` | `duel_pit`، `iron_flats` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| حارس المسبك (`boss_forge`) | NEEDS_POLISH | [boss_forge](../src/minigames/boss_forge.gd) | [boss_hunter_brain](../src/ai/brains/boss_hunter_brain.gd) | `movement_action` | `crate_yard` | زعيم: لم يُعتمد التوازن بمحاكاة ممثلة |
| العملاق (`boss_colossus`) | NEEDS_POLISH | [boss_colossus](../src/minigames/boss_colossus.gd) | [boss_hunter_brain](../src/ai/brains/boss_hunter_brain.gd) | `movement_action` | `vortex_ring` | زعيم: لم يُعتمد التوازن بمحاكاة ممثلة |
| المدرعة (`boss_dreadnought`) | NEEDS_POLISH | [boss_dreadnought](../src/minigames/boss_dreadnought.gd) | [boss_hunter_brain](../src/ai/brains/boss_hunter_brain.gd) | `movement_action` | `iron_flats` | زعيم: لم يُعتمد التوازن بمحاكاة ممثلة |
| السيّد (`boss_sovereign`) | NEEDS_POLISH | [boss_sovereign](../src/minigames/boss_sovereign.gd) | [boss_hunter_brain](../src/ai/brains/boss_hunter_brain.gd) | `movement_action` | `vortex_ring` | زعيم: لم يُعتمد التوازن بمحاكاة ممثلة |
| سباق الصواريخ (`sabaq_sawarikh`) | NEEDS_POLISH | [sabaq_sawarikh](../src/minigames/sabaq_sawarikh.gd) | [racer_armed_brain](../src/ai/brains/racer_armed_brain.gd) | `atv` | `dune_circuit`، `neon_spiral`، `frost_hairpin`، `magma_ring`، `sky_causeway`، `alula_rain`، `sinbad_coast`، `pharaoh_valley` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| حِرْز (`relic_hold`) | NEEDS_POLISH | [relic_hold](../src/minigames/relic_hold.gd) | [relic_brain](../src/ai/brains/relic_brain.gd) | `movement_action` | `star_meadow`، `gem_hollow` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| المطارد (`tag_hunt`) | NEEDS_POLISH | [tag_hunt](../src/minigames/tag_hunt.gd) | [tag_brain](../src/ai/brains/tag_brain.gd) | `movement_action` | `star_meadow`، `paint_grid` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| حصار القواعد (`base_siege`) | NEEDS_POLISH | [base_siege](../src/minigames/base_siege.gd) | [siege_brain](../src/ai/brains/siege_brain.gd) | `movement_action` | `iron_flats`، `crate_yard` | مراجعة اللعب/الجهاز والوضوح والتوازن الموسع متبقية |
| الألواح الجارفة (`drift_floes`) | NEEDS_BALANCE | [drift_floes](../src/minigames/drift_floes.gd) | [generic_brain](../src/ai/brains/generic_brain.gd) | `movement_action` | `vortex_ring`، `storm_ring` | الخبير لا يتفوق على السهل في العينة السابقة |
| نزال الثنائيات (`duo_clash`) | NEEDS_BALANCE | [duo_clash](../src/minigames/duo_clash.gd) | [duo_brain](../src/ai/brains/duo_brain.gd) | `movement_action` | `sweeper_ring`، `bumper_bowl` | تعادل في50% من العينة السابقة؛ الخبير لا يتفوق على السهل في العينة السابقة |

## ملاحظات بصرية محددة

- `goal_guard` عمودي: الملعب ظاهر والنص مقروء؛ زر الاندفاع يقترب من الحافة السفلية للملعب، ويحتاج فحص حجب اليد على جهاز حقيقي.
- `symbol_echo` عمودي: الحلبة أصغر من المساحة المتاحة، وتحتاج تكبيرًا مدروسًا في مرحلة الكاميرا/الصقل.
- `sabaq_sawarikh` أفقي: المركبات وخط البداية والكراتين ظاهرة في الخريطة الأولى؛ هذه لقطة بداية فقط، لا اعتماد إكمال جميع الخرائط.
- فحص اللمس الرباعي السابق يبقي اللاعبين داخل مساحة الكاميرا، لكن وضوح المركبات في العوالم الواسعة على هاتف صغير ما زال غير معتمد.

هذه الملاحظات لا تستبدل مصفوفةQA الكاملة للمرحلة46.
