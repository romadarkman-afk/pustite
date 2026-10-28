# Картинки для карты: что заменить заглушками

Что в игре сейчас нарисовано кодом или сделано заглушкой и ждёт настоящей картинки. Готовый файл кладётся на место с тем же именем, код менять не надо (кроме травы: её надо включить, см. ниже).

Общий хвост для каждого промпта: `Photorealistic, gritty, desaturated, cold natural light, 1890s rural Russia, cinematic still, no text, no logos, no borders, no watermark.`

## Люк убежища: `game/assets/village/hatch.png`

Сейчас там процедурная заглушка 192×96 (делает `tools/make_hatch.py`). Люк лежит на земле у дома, виден сверху под тем же углом камеры, что и дома.

```
A wooden cellar trapdoor lying flat on packed dirt, seen from a high three-quarter angle (about 55 degrees above the ground), the same camera as a top-down village game. Two weathered grey planks wide, iron strap hinges and a ring handle, one corner slightly raised and dark underneath, damp moss at the edges, a little dirt on top. Wide horizontal shape, about 2:1. Isolated on a flat pure magenta background (#FF00FF), the trapdoor must not contain magenta. No ground, no shadow outside the object.
```

Размер любой с отношением около 2:1. Игра ставит люк шириной 62 единицы поля.

## Трава: `grass_green_sheet.png`, `grass_dry_sheet.png`

Промпты уже есть в `docs/art-prompts-weather.md` (раздел «Трава»). Пока там заглушка, пучки выключены флагом `GroundFx.grass_enabled = false`: по заглушке они выглядели как зелёная щётка поверх земли. Когда придёт настоящий атлас, в `game/scripts/village/ground_fx.gd` поставить `grass_enabled = true` и посмотреть `--weather`.

## Листья: `leaf_sheet.png`

Промпт в `docs/art-prompts-weather.md` («Осенние листья»). Размер на поле уже уменьшен до 0,05–0,09 от картинки (было 0,12–0,2), одновременно не больше 12 штук. Если настоящие листья на глаз всё равно крупные, правится `_leaves()` в `weather_layer.gd`.

## Отражения в воде

Тени падают от домов, фонарей, реквизита и жителей. Отражение нужно только предметам у самой воды, а в игре у воды нет ни одного такого предмета: дома отодвинуты от реки. Если хочется отражений, нужны две вещи:

1. Предмет у воды: мостки, лодка, ивы или причал. Лодка (`prop_boat`) уже есть, ей нужен берег.
2. Маска воды карты (`game/assets/village/water_ground*.png`, белое это вода). Сейчас маски собраны автоматически и грубо. Если нарисовать точнее, шейдеру отражения будет проще.

Отдельный шейдер отражений пока не писался.
