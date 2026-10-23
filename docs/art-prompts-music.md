# Музыкальные темы (TASK-082)

Шесть тем, каждая 60–90 с и зациклена. Пока файлов нет, игра молчит там, где тема должна играть, и звучит как раньше. Положил файл с нужным именем в `game/assets/music/` и тема включилась, код менять не надо.

| Файл | Где играет | Настроение |
|---|---|---|
| `theme_act1.ogg` | пролог и итог акта I (деревня, осень) | тихая тревога, одна мелодия на гуслях или скрипке, редкие удары по струне |
| `theme_act2.ogg` | пролог и итог акта II (мельница, поздняя осень) | вода и дерево, ровный ритм колеса, низкий гул, мелодия сбивается |
| `theme_act3.ogg` | пролог и итог акта III (монастырь, зима) | хор без слов, колокол вдали, холодные длинные ноты |
| `theme_act4.ogg` | пролог и итог акта IV (станция, весна) | рельсы, дальний гудок, тёплая струнная нота, надежда с трещиной |
| `theme_pair.ogg` | утро, когда кто-то из живых потерял пару | одна мелодия, почти без сопровождения, не слезливая |
| `theme_climax.ogg` | у двери в последнюю ночь главы | пульс, нарастание, без мелодии, чтобы не перебить стук |

Итог акта играет тему, только если люди выжили. При поражении звучит прежняя тема конца.

## Требования к файлу

- Формат OGG Vorbis, стерео, 44,1 кГц, качество 5 и выше.
- Длина 60–90 с, конец тихо переходит в начало (цикл без щелчка).
- Громкость −16 LUFS ±1,5.
- Проверка: `python3 tools/check_music.py` из корня репозитория. Печатает длину и громкость каждой темы и замечания по стыку цикла.
- Лицензия: Suno и Udio дают права на коммерческое использование только на платных тарифах и только для треков, созданных в период подписки. Перед добавлением сохрани скриншот страницы трека с тарифом и впиши источник в `docs/sound-sources.md`. Для CC0-треков запиши автора и ссылку.

## Промпты для Suno и Udio

Добавляй в каждый: `instrumental, no vocals, seamless loop, cinematic folk horror, dark ambient, 1890s rural Russia, no drums unless stated, 75 seconds`.

**Акт I**
```
Lonely hurdy-gurdy and low bowed fiddle, slow sparse melody in minor, long silences, distant wind, a single plucked string now and then, cold anxious calm before a storm.
```

**Акт II**
```
Water-wheel rhythm made of wooden clicks, deep drone, detuned folk fiddle melody that keeps losing its way, wet creaking wood, damp autumn dread.
```

**Акт III**
```
Wordless male choir in a stone hall, slow cold sustained notes, one far bell, no melody beyond three notes, winter silence between phrases.
```

**Акт IV**
```
Steel rails rhythm far away, distant train whistle, warm string note slowly rising, fragile hope with a crack in it, spring morning in fog.
```

**Тема пары**
```
Solo cello with soft piano, one simple tender melody, very quiet, grief without melodrama, ends unresolved.
```

**Кульминация**
```
Heartbeat pulse building over 75 seconds, low strings tremolo, sub bass swells, metallic scrapes, no melody, tension that never releases, loops into the beginning.
```
