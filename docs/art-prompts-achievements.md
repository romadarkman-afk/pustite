# Иконки достижений (TASK-088)

Достижений 19, не 18, как было в плане: добавилась «Спасённая связь». Пока картинок нет, в Книге посёлка стоят значки из набора `Glyph`. Положи готовый файл на место, код подхватит его сам.

- Файл: `game/assets/ui/ach/<номер>.png`, квадрат, ориентир 256×256, прозрачный фон.
- Генераторы часто не дают прозрачность: проси сплошной пурпурный фон `#FF00FF`, а потом прогони папку скриптом `python3 tools/prepare_ach_icons.py ПАПКА`. Он вырежет фон, обрежет поля, впишет в 256×256 и сложит файлы куда надо. Имя файла в папке должно быть номером достижения (`oil.png`, `act3.jpg`).
- Не полученное достижение игра затемняет сама, отдельной серой версии не нужно.
- Одна и та же рамка у всех, чтобы ряд читался как набор значков.

Общий хвост для каждого промпта:

```
Round embossed medallion, hand-engraved dark pewter relief with warm amber highlights and a thin worn rim, one centered emblem, folk motif of 1890s rural Russia, subtle patina, soft top light, no text, no letters, no numbers. Isolated on a flat pure magenta background (#FF00FF), the medallion must not contain magenta. No ground, no shadow outside the medallion.
```

Эмблема в центре, по одной на достижение. Подставь в начало промпта:

| Номер | Название | Эмблема |
|---|---|---|
| `night1` | Первая ночь | A single candle flame in a small dark window, one pane lit. |
| `open_door` | Открытая дверь | A plank door ajar, warm light spilling out, three small shadows on the threshold. |
| `closed_door` | Засов | A heavy iron bolt slid across a closed plank door. |
| `instinct` | Чутьё | A single watchful eye with a narrow vertical pupil, lashes like fir needles. |
| `mistake` | Ошибка | A wooden tally stick snapped in two, a dark stain on the break. |
| `mourning` | Траур | A black cloth tied on a village gate post, one small candle beside it. |
| `last_one` | Последние | Two short candle stubs side by side, one flame guttering. |
| `debtor` | Долг | An iron key lying across a notched tally stick. |
| `oil` | Масло | A small clay flask of lamp oil with a wick burning in its neck. |
| `forest_call` | Голос из леса | The edge of a dark fir forest with a pale mist swirl shaped like an open mouth, no face. |
| `guest_secret` | Чужая тайна | A folded letter with a cracked red wax seal. |
| `three_stars` | Три звезды | Three small brass stars in a row, the middle one slightly larger. |
| `act1` | Уход к мельнице | A water mill wheel with a footpath leading to it. |
| `act2` | Вверх по реке | A wooden rowing boat with a hanging lantern on dark river water. |
| `act3` | Колокол за спиной | A bronze church bell with its rope, seen slightly from below. |
| `act4` | Последний поезд | A steam locomotive lamp glowing through fog, two rails running to it. |
| `dark_side` | Сторона леса | A single curved fang with a thin red edge-light. |
| `whole_family` | Пустой дом | A small wooden house with all windows dark, the door open, an empty chair on the porch. |
| `saved_bond` | Спасённая связь | Two hands holding a thin red thread between them, the thread taut but unbroken. |

Образец полного промпта (`oil`):

```
A small clay flask of lamp oil with a wick burning in its neck. Round embossed medallion, hand-engraved dark pewter relief with warm amber highlights and a thin worn rim, one centered emblem, folk motif of 1890s rural Russia, subtle patina, soft top light, no text, no letters, no numbers. Isolated on a flat pure magenta background (#FF00FF), the medallion must not contain magenta. No ground, no shadow outside the medallion.
```
