# Четыре двери по картам (TASK-078)

Игра берёт картинки двери по месту главы. Если файлов нет, работает общая дверь `door_closed.png` и `door_open.png` с оттенком карты. Когда положишь пару файлов, дверь этого места заменится, код менять не надо.

| Место | Карта | Файлы в `game/assets/ui/` | Свеча стоит |
|---|---|---|---|
| Изба | Деревня (акт I) | `door_izba_closed.png`, `door_izba_open.png` | справа, ниже середины |
| Мельница | Мельница (акт II) | `door_mill_closed.png`, `door_mill_open.png` | справа |
| Келья | Монастырь (акт III) | `door_cell_closed.png`, `door_cell_open.png` | слева |
| Вагон | Станция (акт IV) | `door_wagon_closed.png`, `door_wagon_open.png` | справа, чуть выше |

Закрытая и открытая картинки каждого места идут парой: тот же размер 1224×1824, тот же ракурс, те же доски и петли, у открытой щель светится шире. Без текста, без рамки. Пока нет обеих картинок пары, берётся общая дверь.

Общее для каждой: вид прямо в дверь, вертикальный кадр 2:3, тёмная ночь, тёплый свет из щелей, тот же стиль и толщина контура, что у `door_closed.png`. Справа или слева (как в таблице) остаётся свободное место под свечу: игра сама рисует свечу и тень, в картинку их не рисовать.

Промпты (к каждому добавить хвост `Hand-painted, dark outlines, same style as the existing village door, no text, no logos, no watermark.`):

**Изба**
```
Front view of a heavy wooden plank door of a Russian peasant izba at night, vertical frame 2:3. Weathered grey boards, iron strap hinges, a thick iron bolt across the middle, warm orange light leaking through the gaps between boards, a wooden threshold with snow. Leave empty dark wall space on the right side.
```

**Мельница**
```
Front view of the plank door of a water mill at night, vertical frame 2:3. Wet dark wood, green moss at the bottom, rusty iron bolt, flour dust on the threshold, cold blue moonlight from the side and warm orange light through the cracks, a rope and a hook beside the door. Leave empty space on the right side.
```

**Келья**
```
Front view of a monastery cell door at night, vertical frame 2:3. Low arched dark oak door set in whitewashed stone, black iron studs, a small iron latch instead of a bolt, a thin line of candle light under the door, worn stone threshold. Leave empty space on the left side.
```

**Вагон**
```
Front view of a railway carriage sliding door at night, vertical frame 2:3. Dark green painted metal and wood, rust streaks, a heavy iron latch bar, small round rivets, fog at the bottom, a dim yellow lamp light through a narrow gap. Leave empty space on the right side, slightly higher up.
```

Чтобы проверить: положить файлы, запустить партию на нужной карте, дойти до двери. Свеча и тень встанут по таблице. Если свеча ложится на деталь двери, скажи, в какую сторону сдвинуть: координаты лежат в `DOOR_STYLES` в `game/scripts/ui/atmosphere.gd`.
