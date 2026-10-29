# Источники звука

Сторонние записи и их авторство перечислены ниже; источники и лицензии указаны в таблице. В меню играет заглавная песня `song_pustite.ogg` («За дверями тишина»). `menu_theme.wav` остаётся запасной процедурной темой, если песня отсутствует. `river_theme.wav` звучит во вступлении у реки, `day.ogg` днём, `night.ogg` ночью и у двери. Godot сжимает WAV при импорте.

| Файлы в игре | Исходная запись | Автор |
| --- | --- | --- |
| `music/menu_theme.wav` | Оригинальная процедурная тема, `game/tools/make_menu_theme.py` | Создана для проекта, внешних сэмплов нет |
| `music/song_pustite.ogg` | MP3 «За дверями тишина», предоставленный автором проекта; преобразован в Ogg Vorbis q5, выровнен до −16.2 LUFS / −4.1 dBTP | Пользовательский мастер |
| `music/river_theme.wav` | Оригинальная процедурная тема, `game/tools/make_river_theme.py` | Создана для проекта, внешних сэмплов нет |
| `music/day.ogg` | Оригинальная процедурная тема (ре мажор), `tools/make_day_night_music.py` | Создана для проекта, внешних сэмплов нет. Заменила CC0 Mystery (PolygonDan) в TASK-100.1 |
| `music/night.ogg` | Оригинальная процедурная тема (ми фригийский), `tools/make_day_night_music.py` | Создана для проекта, внешних сэмплов нет. Заменила Dark Place (SkyleTheFrench) в TASK-100.1 |
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

## Кандидаты на замену по спектрам, 29.10.2026

В игре 48 музыкальных файлов и 64 эффекта. Музыка включает темы дня и ночи по главам, меню, вступления, концовки и песни. Эффекты покрывают погоду, деревню, двери и шаги, страх, станцию, интерфейс и исходы партии. Спектральная проверка помогает найти перекос громкости и частот; художественное решение нужно принимать после прослушивания на телефоне и в наушниках.

### Приоритет 1: голоса жителей

В `assets/voice` сейчас лежат папки вступлений, папки `bark` нет. Функция `voice()` поэтому проигрывает на каждую реплику 2–4 коротких `blip.ogg`. Это и создаёт писк вместо голоса. Сначала нужны 8 коротких естественных возгласов для каждого из семи типов голоса: женщина/мужчина старшего, среднего и молодого возраста, плюс мальчик. Итого 56 спокойных вариантов; страх, горе и ярость можно добавить позже. Код уже умеет выбирать случайный вариант и повторять тональность одного жителя.

### Приоритет 2: страх и реакции

Заменить синтетические `weep.ogg`, `whisper.ogg`, `gasp.ogg`, `growl.ogg`, `call_far.ogg`, `scratch.ogg`, `breath_2.ogg` и `breath_3.ogg`. В первую очередь нужны живые шёпот, плач и дыхание за дверью; затем дальний зов и рычание. `breath.ogg` тоже тихий: около −39 dBFS по среднему уровню.

### Приоритет 3: деревенский фон и шаги

- `amb_day.ogg`: 28 секунд, средний уровень −40.2 dBFS, пик −17.2 dBFS; 98% энергии приходится на 2–8 кГц. На телефоне слой может теряться, а по тембру остаются преимущественно высокие птичьи звуки. Проверить усиление и заменить на более сбалансированную запись ветра, птиц и дальних звуков деревни.
- `life_murmur.ogg`, `life_dog.ogg`, `life_hens.ogg` и `mill_wheel.ogg` созданы генератором. Нужны настоящие голоса людей и животных, затем скрип колеса и жерновов.
- `roof_steps.ogg`: 1.3 секунды, пик −22 dBFS, в коде добавляется ещё −5 или −10 dB. Это может стать почти неслышно. Нужны несколько шагов по деревянному чердаку или крыше, с разными ботинками и темпом.
- `death.ogg`: 85% энергии ниже 120 Гц. На динамике телефона такой сигнал заметно теряет тело. Добавить древесный удар и средние частоты.

### Приоритет 4: дождь и предметные звуки

У `amb_rain_light.ogg`, `amb_rain_drops.ogg` и `amb_rain_roof.ogg` много энергии в верхней середине; `amb_rain.ogg` почти ровный по уровню. Прослушать переходы и циклы, затем заменить те слои, которые воспринимаются как шипение. Для дверей, щеколд, досок и колокола выбрать близкие к русской деревне записи. У текущих `door_open.ogg` и `door_shut.ogg` декодированный пик выше 0 dBFS; оставить запас до пика, если звук звучит жёстко.

### Приоритет 5: станция и сигналы интерфейса

`rails.ogg`, `train.ogg`, `typewriter.ogg` и `whistle.ogg` синтезированы скриптом. Прослушать их в сцене станции и заменить на записи с подходящей дистанцией и фактурой. `blip`, `tick`, `reveal`, `job_done`, `job_fail`, `win`, `lose`, `death` и `exile` тоже синтезированы. Их можно постепенно заменить звуками дерева, железа и колокола, сохранив различимость событий.

### Первые источники для примерки

- [Park ambiences](https://opengameart.org/content/park-ambiences), CC0: полевые записи птиц, реки и ветра. Записи сделаны в парке Австралии; их надо проверить на соответствие русской деревне, а большие WAV укоротить и сжать.
- [Rain in the Gutter Loop](https://opengameart.org/content/rain-gutter-loop), CC0: дождь по крыше и водостоку, уже зациклен.
- [Horror breathing](https://opengameart.org/content/horror-breathing), CC0: записанное дыхание для сцен за дверью.
- [Different steps on wood, stone, leaves, gravel and mud](https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud), CC0: короткие шаги по основным поверхностям.
- [Various Sound Effects](https://opengameart.org/content/various-sound-effects), CC0: записанные двери, замки, колокол и скрипы.

Это список кандидатов. Перед переносом каждого файла в игру нужно проверить сам звук, лицензию и уровень на смартфонном динамике.
