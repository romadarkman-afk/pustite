# Источники звука

Сторонние записи и их авторство перечислены ниже; заявленная для них лицензия в исходном аудиопакете — CC0. Четыре музыкальные темы сделаны процедурно скриптами проекта без внешних сэмплов. `menu_theme.wav` звучит в меню, `river_theme.wav` во вступлении у реки, `day.ogg` днём, `night.ogg` ночью и у двери. Godot сжимает WAV при импорте.

| Файлы в игре | Исходная запись | Автор |
| --- | --- | --- |
| `music/menu_theme.wav` | Оригинальная процедурная тема, `game/tools/make_menu_theme.py` | Создана для проекта, внешних сэмплов нет |
| `music/river_theme.wav` | Оригинальная процедурная тема, `game/tools/make_river_theme.py` | Создана для проекта, внешних сэмплов нет |
| `music/day.ogg` | Оригинальная процедурная тема (ре мажор), `tools/make_day_night_music.py` | Создана для проекта, внешних сэмплов нет. Заменила CC0 Mystery (PolygonDan) в TASK-101 |
| `music/night.ogg` | Оригинальная процедурная тема (ми фригийский), `tools/make_day_night_music.py` | Создана для проекта, внешних сэмплов нет. Заменила Dark Place (SkyleTheFrench) в TASK-101 |
| `music/end_dawn.ogg` | [Forget Me Not](https://opengameart.org/content/forget-me-not) | Kistol |
| `music/end_dark.ogg` | [Game Over Dark Short Music Clips](https://opengameart.org/content/game-over-dark-short-music-clips) | Robin Lamb |
| `sfx/amb_day.ogg` | [Ambient Bird Sounds](https://opengameart.org/content/ambient-bird-sounds) | isaiah658 |
| `sfx/amb_night.ogg` | [Crickets Ambient Noise](https://opengameart.org/content/crickets-ambient-noise-loopable), [wind whoosh loop](https://opengameart.org/content/wind-whoosh-loop) | Ted Kerr, SketchMan3 |
| `sfx/amb_dusk.ogg` | [wind whoosh loop](https://opengameart.org/content/wind-whoosh-loop) | SketchMan3 |
| `sfx/amb_river.ogg` | [Sea and river wave sounds](https://opengameart.org/content/sea-and-river-wave-sounds) | RandomMind |
| `sfx/knock.ogg`, `door_open.ogg`, `door_shut.ogg`, `creak.ogg` | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | rubberduck |
| `sfx/tap.ogg`, `bell.ogg` | [UI Sound Effects](https://opengameart.org/content/ui-sound-effects-button-clicks-user-feedback-notifications) | Robin Lamb |
| `sfx/human_cry_f.ogg` | [Female Scream 1](https://opengameart.org/content/female-scream-1) | AuraVoice / Nocturnal_Vanguard |
| `sfx/upyr_cry.wav` | [Monster SFX](https://opengameart.org/content/monster-sfx) | marcelofg55 |
| `sfx/floorboard.ogg`, `hammer.ogg`, `latch.ogg` | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | rubberduck |
| `sfx/roof_steps.ogg` | [Footsteps](https://opengameart.org/content/footsteps-0) | GboxMikeFozzy |
| `sfx/growl.ogg`, `breath.ogg` | [80 CC0 creature SFX](https://opengameart.org/content/80-cc0-creature-sfx) | rubberduck |
| `sfx/cry_far.ogg` | [Male Grunt/Yelling sounds](https://opengameart.org/content/male-gruntyelling-sounds) | HaelDB |
| `sfx/scare.ogg` | [Dark Ambiences](https://opengameart.org/content/dark-ambiences) | Ogrebane |
| `sfx/breath_2.ogg`, `breath_3.ogg` | Синтез скриптом `game/tools/make_dread.py` (шум через полосовой фильтр, огибающая вдоха и выдоха, срез верха под «через доску»). Третий вариант дыхания за дверью, `breath.ogg`, записан (rubberduck, см. выше) | Созданы для проекта |
| `sfx/amb_wind.ogg`, `amb_rain.ogg`, `amb_blizzard.ogg`, `life_murmur.ogg`, `life_dog.ogg`, `life_hens.ogg`, `mill_wheel.ogg` | Синтез скриптом `game/tools/make_weather_sfx.py` (шум, полосовые фильтры, формантные слоги) | Созданы для проекта, внешних записей нет |

| `sfx/blip.ogg`, `dawn.ogg`, `death.ogg`, `exile.ogg`, `heartbeat.ogg`, `job_done.ogg`, `job_fail.ogg`, `lose.ogg`, `tick.ogg`, `win.ogg`, `reveal.ogg` | Синтез скриптом `game/tools/make_sfx.py` | Созданы для проекта, внешних записей нет |
| `sfx/reveal_2.ogg`, `reveal_3.ogg` | Синтез скриптом `game/tools/make_prologue_sfx.py` | Созданы для проекта |
| `sfx/cup_break.ogg` | Синтез скриптом `game/tools/make_scene_sfx.py` | Создан для проекта |
| `sfx/rails.ogg`, `train.ogg`, `typewriter.ogg`, `whistle.ogg` | Синтез скриптом `game/tools/make_station_sfx.py` | Созданы для проекта |
| `sfx/scratch.ogg`, `weep.ogg`, `whisper.ogg`, `gasp.ogg`, `call_far.ogg` | Синтез скриптом `game/tools/make_dread.py` | Созданы для проекта |
| `sfx/human_cry_m.ogg` | Скрипт не найден; рядом лежит `human_cry_f.ogg` (AuraVoice) | Происхождение не установлено |

## Что в таблице не сходится (аудит F-17, TASK-100)

- `sfx/hammer.ogg`, `floorboard.ogg`, `latch.ogg` указаны выше как записи rubberduck, но `game/tools/make_scene_sfx.py` создаёт файлы с теми же именами. В репозитории лежит одна версия (5 КБ каждый, один коммит «Add files via upload»), какая именно, по коммитам не определить. Оба варианта допустимы: скрипт проекта или запись CC0. Чтобы закрыть вопрос, послушай файлы и сравни с `make_scene_sfx.py`.
- `sfx/human_cry_m.ogg`: источник не записан.
- Лицензии страниц OpenGameArt в этой среде проверить нельзя (доступ к сайту закрыт). В таблице указана лицензия из исходного аудиопакета. Если на странице автора стоит CC-BY, требуется упоминание автора: в игре оно уже есть, настройки, «Об игре» (все имена из таблицы), но нужен ещё текст лицензии и ссылка в описании магазина.
- Файлы `music/menu.ogg` (Cleyton Kauffman) и `sfx/human_cry.wav` (HaelDB) удалены из репозитория как неиспользуемые; в их источнике запись осталась только в истории git.

## Что синтезировано и звучит хуже записи (TASK-081)

`weep.ogg` (сдавленный плач), `whisper.ogg`, `gasp.ogg`, `growl.ogg`, `call_far.ogg` делает `tools/make_dread.py` формулами. Голос формулами выходит искусственным. Заменить записями CC0 нужно вручную: у среды, где работает Claude, нет доступа к opengameart.org и freesound.org. Кладёшь файл `.ogg` с тем же именем в `game/assets/sfx/`, код не меняется. Длина `weep.ogg` 2–3 с, `call_far.ogg` 2 с, громкость пика не выше −3 дБ. Перед добавлением записи проверь лицензию на странице автора и впиши её в таблицу выше.

