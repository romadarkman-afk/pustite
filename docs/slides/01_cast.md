# Персонажи и лица

Лица берутся с игровых портретов (`game/assets/folk/realistic`), поэтому герой в комиксе совпадает с тем, кто стоит на поле. Для каждого персонажа есть **картинка-эталон** `refs/ref_<id>.jpg` (портрет из игры, увеличенный) и **промпт листа-эталона**.

## Как делать лист-эталон (шаг А, по одной на персонажа)
1. Новый чат в проекте. Приложите `refs/ref_<id>.jpg`.
2. Вставьте промпт листа ниже. ChatGPT нарисует фотографического «актёра» с тем же лицом: три ракурса головы и фигура в рост на сером фоне.
3. Если лицо не то, напишите `Closer match to the reference: same age, same bones, same eyes, same hair and beard` и повторите.
4. Сохраните как `cast_<id>.png`. Эти файлы потом прикладываются к каждой картинке с этим человеком.

Лист-эталон каждого персонажа делается один раз и не идёт в игру.

## Правило для сюжетных колод

Именные жители могут погибнуть по ходу кампании (смерть насовсем), поэтому в колодах глав их нет. В главах работают гости, лица сюжета (мельник, Игнат, Анфиса, смотритель) и безымянная толпа. Лица именных жителей показаны в их предысторях. Игра сама подставит предысторию, когда игрок встретит или потеряет человека.

## Привязка портретов (для игры, TASK-117)
Сейчас игра выдаёт портрет жителю случайно из пула по полу. Чтобы Марина в комиксе совпадала с Мариной на поле, в кампании портрет должен закрепляться за именем. Таблица ниже уже согласована с предысториями.

| id | Имя | Роль | Портрет в игре | Пол и возраст |
|---|---|---|---|---|
| marina | Марина | перевозчица | `f9` | f, 34 |
| lida | Лида | учительница | `f12` | f, 61 |
| zhenya | Женя | знахарка, фельдшер | `f10` | f, 47 |
| rita | Рита | часовщица | `f3` | f, 29 |
| nina | Нина | охотница на волков | `f11` | f, 58 |
| polina | Полина | кузнец ножей | `f1` | f, 56 |
| timur | Тимур | могильщик | `f2` | m, 41 |
| kostya | Костя | потерял сестру | `f4` | m, 21 |
| tikhon | Тихон | сторож моста | `f13` | m, 54 |
| zakhar | Захар | трактирный подметальщик | `f7` | m, 23 |
| misha | Миша | следопыт, вдовец | `f8` | m, 45 |
| vadim | Вадим | садовник | `f14` | m, 26 |
| gordey | Гордей | солдат без полка | `guest_soldier` | m, 25 |
| agafya | Агафья | вдова с телегой | `guest_widow` | f, 40 |
| efim | Ефим | торговец оберегами | `guest_merchant` | m, 50 |
| stepan | Степан | рабочий депо | `guest_worker` | m, 45 |
| pisar | Аркадий | писарь | `guest_clerk` | m, 50 |
| ignat | Брат Игнат | монах, рассказчик акта III | `npc_abbot` | m, 75 |
| anfisa | Сестра Анфиса | послушница | `npc_nun` | f, 22 |
| smotritel | Смотритель | смотритель станции | `npc_stationmaster` | m, 60 |
| melnik | Мельник Савелий | хозяин мельницы | `npc_worker` | m, 60 |
| extra_thin | Худой старик | статист | `f5` | m, 72 |
| extra_boy | Мальчик | статист | `f15` | m, 14 |
| extra_pilgrim | Странник | статист | `f16` | m, 55 |

## Марина · перевозчица

- Эталон из игры: `refs/ref_marina.jpg` (портрет `f9`)
- Лицо: woman about 34 who looks older than her years, auburn hair under a brown headscarf with red ties, light freckles over the nose, large sad grey-blue eyes, narrow tired face, pale lips, a look of someone who keeps listening for a call from the far bank
- Одежда: patched linen blouse with a dark worn skirt, a brown shawl, an oilskin cape on the river, rope-scarred hands

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: woman about 34 who looks older than her years, auburn hair under a brown headscarf with red ties, light freckles over the nose, large sad grey-blue eyes, narrow tired face, pale lips, a look of someone who keeps listening for a call from the far bank.
Costume: patched linen blouse with a dark worn skirt, a brown shawl, an oilskin cape on the river, rope-scarred hands.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Лида · учительница

- Эталон из игры: `refs/ref_lida.jpg` (портрет `f12`)
- Лицо: woman about 61, grey hair under a black fringed wool shawl, narrow severe face with deep lines, grey eyes, thin straight pale lips, a head slightly tilted as if she is always listening to a classroom that is empty
- Одежда: black fringed shawl, long dark patched dress, ink-stained fingertips, a small thin notebook

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: woman about 61, grey hair under a black fringed wool shawl, narrow severe face with deep lines, grey eyes, thin straight pale lips, a head slightly tilted as if she is always listening to a classroom that is empty.
Costume: black fringed shawl, long dark patched dress, ink-stained fingertips, a small thin notebook.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Женя · знахарка, фельдшер

- Эталон из игры: `refs/ref_zhenya.jpg` (портрет `f10`)
- Лицо: woman about 47, light-brown hair pulled into a low bun, long stern face, thin tight mouth, green-grey eyes with tired lids, weathered skin with sun lines, two vertical frown lines between the brows
- Одежда: brown wool shawl over a faded red-patterned sarafan, a wicker basket of dried herbs on her arm, little cloth pouches on her belt

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: woman about 47, light-brown hair pulled into a low bun, long stern face, thin tight mouth, green-grey eyes with tired lids, weathered skin with sun lines, two vertical frown lines between the brows.
Costume: brown wool shawl over a faded red-patterned sarafan, a wicker basket of dried herbs on her arm, little cloth pouches on her belt.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Рита · часовщица

- Эталон из игры: `refs/ref_rita.jpg` (портрет `f3`)
- Лицо: woman about 29 who looks younger, very pale skin, long thick blonde braid over one shoulder, light blue-grey eyes, small serious mouth, high forehead, calm unblinking look
- Одежда: plain linen blouse with a dark apron full of small tools, a magnifying lens on a cord, fine steady hands

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: woman about 29 who looks younger, very pale skin, long thick blonde braid over one shoulder, light blue-grey eyes, small serious mouth, high forehead, calm unblinking look.
Costume: plain linen blouse with a dark apron full of small tools, a magnifying lens on a cord, fine steady hands.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Нина · охотница на волков

- Эталон из игры: `refs/ref_nina.jpg` (портрет `f11`)
- Лицо: stout woman about 58, heavy jowls and strong jaw, grey hair under a brown headscarf, severe grey eyes under a heavy brow, deep lines from nose to mouth, a face that does not smile
- Одежда: dark floral dress under a sheepskin vest, fur hat when outdoors, old long rifle on a strap

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: stout woman about 58, heavy jowls and strong jaw, grey hair under a brown headscarf, severe grey eyes under a heavy brow, deep lines from nose to mouth, a face that does not smile.
Costume: dark floral dress under a sheepskin vest, fur hat when outdoors, old long rifle on a strap.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Полина · кузнец ножей

- Эталон из игры: `refs/ref_polina.jpg` (портрет `f1`)
- Лицо: woman about 56, deeply lined severe face, grey eyebrows, pale blue-grey eyes, thin straight mouth, brown headscarf with a faded red pattern pulled low, a stocky solid build
- Одежда: heavy patched brown coat over a scorched leather apron, wooden beads wound round one wrist, burn scars on both forearms

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: woman about 56, deeply lined severe face, grey eyebrows, pale blue-grey eyes, thin straight mouth, brown headscarf with a faded red pattern pulled low, a stocky solid build.
Costume: heavy patched brown coat over a scorched leather apron, wooden beads wound round one wrist, burn scars on both forearms.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Тимур · могильщик

- Эталон из игры: `refs/ref_timur.jpg` (портрет `f2`)
- Лицо: man about 41, thick red-brown beard with a few grey hairs, blue eyes under heavy lids, broken nose bridge, deep creases at the eyes, flat worker's cap
- Одежда: worn coat with a fur collar, mud to the knees, a shovel always in reach

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: man about 41, thick red-brown beard with a few grey hairs, blue eyes under heavy lids, broken nose bridge, deep creases at the eyes, flat worker's cap.
Costume: worn coat with a fur collar, mud to the knees, a shovel always in reach.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Костя · потерял сестру

- Эталон из игры: `refs/ref_kostya.jpg` (портрет `f4`)
- Лицо: young man about 21, light-brown hair under a flat cap, light blue eyes, thin clean-shaven face, sharp cheekbones, restless alert look, a small old scar on the chin
- Одежда: brown vest over a maroon shirt, red sash belt, patched trousers

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: young man about 21, light-brown hair under a flat cap, light blue eyes, thin clean-shaven face, sharp cheekbones, restless alert look, a small old scar on the chin.
Costume: brown vest over a maroon shirt, red sash belt, patched trousers.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Тихон · сторож моста

- Эталон из игры: `refs/ref_tikhon.jpg` (портрет `f13`)
- Лицо: man about 54, short greying brown hair, long deeply lined weary face, grey stubble, heavy-lidded sad eyes, drooping corners of the mouth
- Одежда: dark long coat, a coil of rope or net over one shoulder, an old kerosene lantern in hand

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: man about 54, short greying brown hair, long deeply lined weary face, grey stubble, heavy-lidded sad eyes, drooping corners of the mouth.
Costume: dark long coat, a coil of rope or net over one shoulder, an old kerosene lantern in hand.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Захар · трактирный подметальщик

- Эталон из игры: `refs/ref_zakhar.jpg` (портрет `f7`)
- Лицо: broad heavy young man of 23 who looks ten years older, short dark hair, thick brow, narrowed stern eyes, square jaw with dark stubble, a nose broken once, a stare that shuts conversations
- Одежда: scorched leather apron over a grey shirt, huge forearms, a worn broom or a hammer

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: broad heavy young man of 23 who looks ten years older, short dark hair, thick brow, narrowed stern eyes, square jaw with dark stubble, a nose broken once, a stare that shuts conversations.
Costume: scorched leather apron over a grey shirt, huge forearms, a worn broom or a hammer.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Миша · следопыт, вдовец

- Эталон из игры: `refs/ref_misha.jpg` (портрет `f8`)
- Лицо: lean man about 45, narrow grey eyes, weathered tanned face with a trimmed stubble, thin lips, a watchful look that checks every corner
- Одежда: fur ushanka with the ear flaps down, sheepskin collar, brown scarf, hunting knife, coil of rope, leather satchel

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: lean man about 45, narrow grey eyes, weathered tanned face with a trimmed stubble, thin lips, a watchful look that checks every corner.
Costume: fur ushanka with the ear flaps down, sheepskin collar, brown scarf, hunting knife, coil of rope, leather satchel.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Вадим · садовник

- Эталон из игры: `refs/ref_vadim.jpg` (портрет `f14`)
- Лицо: thin man about 26 with a prematurely aged face, grey-streaked dark hair falling over the forehead, hollow cheeks, deep tired eyes, stubble, a gentle patient look
- Одежда: torn linen shirt with rolled sleeves, bast shoes with wrapped legs, a long fruit-picking pole, apple juice stains on the cuffs

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: thin man about 26 with a prematurely aged face, grey-streaked dark hair falling over the forehead, hollow cheeks, deep tired eyes, stubble, a gentle patient look.
Costume: torn linen shirt with rolled sleeves, bast shoes with wrapped legs, a long fruit-picking pole, apple juice stains on the cuffs.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Гордей · солдат без полка

- Эталон из игры: `refs/ref_gordey.jpg` (портрет `guest_soldier`)
- Лицо: young soldier about 25, completely shaved head, narrow face with high cheekbones, grey-blue wary eyes, thin lips, sunken cheeks of a man who has not slept for days
- Одежда: olive army greatcoat that is too big for him, shoulder straps, brass buttons, mud and a dark stain on the hem

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: young soldier about 25, completely shaved head, narrow face with high cheekbones, grey-blue wary eyes, thin lips, sunken cheeks of a man who has not slept for days.
Costume: olive army greatcoat that is too big for him, shoulder straps, brass buttons, mud and a dark stain on the hem.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Агафья · вдова с телегой

- Эталон из игры: `refs/ref_agafya.jpg` (портрет `guest_widow`)
- Лицо: woman about 40, dark hair under a heavy black wool shawl, dark circles under grey eyes, pale lips, a face that stopped hoping but keeps smiling softly
- Одежда: black shawl with a patched corner, a small child's handkerchief clutched against the chest, long dark skirt

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: woman about 40, dark hair under a heavy black wool shawl, dark circles under grey eyes, pale lips, a face that stopped hoping but keeps smiling softly.
Costume: black shawl with a patched corner, a small child's handkerchief clutched against the chest, long dark skirt.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Ефим · торговец оберегами

- Эталон из игры: `refs/ref_efim.jpg` (портрет `guest_merchant`)
- Лицо: man about 50, round warm face, crooked friendly smile, laughing lines, small clever dark eyes, brown fur hat
- Одежда: dark long coat with frog fasteners, leather satchel on a strap, a wooden box of thistle-and-salt amulets

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: man about 50, round warm face, crooked friendly smile, laughing lines, small clever dark eyes, brown fur hat.
Costume: dark long coat with frog fasteners, leather satchel on a strap, a wooden box of thistle-and-salt amulets.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Степан · рабочий депо

- Эталон из игры: `refs/ref_stepan.jpg` (портрет `guest_worker`)
- Лицо: man about 45, stern square face, grey stubble, deep-set tired eyes, fur ushanka with ear flaps, soot in the creases of the skin
- Одежда: padded quilted jacket, wrapped felt boots, a small kerosene lantern, black hands

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: man about 45, stern square face, grey stubble, deep-set tired eyes, fur ushanka with ear flaps, soot in the creases of the skin.
Costume: padded quilted jacket, wrapped felt boots, a small kerosene lantern, black hands.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Аркадий · писарь

- Эталон из игры: `refs/ref_pisar.jpg` (портрет `guest_clerk`)
- Лицо: thin man about 50, narrow face, small round wire spectacles, thin pressed lips, cold attentive eyes, black bowler hat
- Одежда: long black greatcoat, a small notebook and a pencil stub, ink on the right index finger

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: thin man about 50, narrow face, small round wire spectacles, thin pressed lips, cold attentive eyes, black bowler hat.
Costume: long black greatcoat, a small notebook and a pencil stub, ink on the right index finger.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Брат Игнат · монах, рассказчик акта III

- Эталон из игры: `refs/ref_ignat.jpg` (портрет `npc_abbot`)
- Лицо: old monk about 75, tall black kamilavka, long white beard and white hair, pale stern eyes, a long straight nose, a gaunt calm face
- Одежда: black wool robe, wooden pectoral cross on a chain, a ring of keys at the belt

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: old monk about 75, tall black kamilavka, long white beard and white hair, pale stern eyes, a long straight nose, a gaunt calm face.
Costume: black wool robe, wooden pectoral cross on a chain, a ring of keys at the belt.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Сестра Анфиса · послушница

- Эталон из игры: `refs/ref_anfisa.jpg` (портрет `npc_nun`)
- Лицо: young novice about 22, black hood and veil, huge sad dark eyes, pale narrow face, trembling lower lip
- Одежда: black habit, a ring of iron keys at the belt, rough hands

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: young novice about 22, black hood and veil, huge sad dark eyes, pale narrow face, trembling lower lip.
Costume: black habit, a ring of iron keys at the belt, rough hands.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Смотритель · смотритель станции

- Эталон из игры: `refs/ref_smotritel.jpg` (портрет `npc_stationmaster`)
- Лицо: man about 60, peaked railway cap with a small imperial eagle badge, grey moustache, deep nasolabial folds, stern pale eyes, a face of a man who has seen the same platform for thirty years
- Одежда: black railway greatcoat with epaulettes, a watch chain, white gloves gone grey, a ledger under the arm and a lantern

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: man about 60, peaked railway cap with a small imperial eagle badge, grey moustache, deep nasolabial folds, stern pale eyes, a face of a man who has seen the same platform for thirty years.
Costume: black railway greatcoat with epaulettes, a watch chain, white gloves gone grey, a ledger under the arm and a lantern.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Мельник Савелий · хозяин мельницы

- Эталон из игры: `refs/ref_melnik.jpg` (портрет `npc_worker`)
- Лицо: heavy man about 60, flour dust in his grey hair and eyebrows, small shrewd eyes, big fleshy hands, a face that counts everything, deep sorrow hidden behind the stare
- Одежда: flour-covered apron over a thick grey sweater, a heavy ring of keys and a small ledger book at the belt

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: heavy man about 60, flour dust in his grey hair and eyebrows, small shrewd eyes, big fleshy hands, a face that counts everything, deep sorrow hidden behind the stare.
Costume: flour-covered apron over a thick grey sweater, a heavy ring of keys and a small ledger book at the belt.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Худой старик · статист

- Эталон из игры: `refs/ref_extra_thin.jpg` (портрет `f5`)
- Лицо: thin old man about 72, long white beard and unkempt white hair, deep-set pale grey eyes, hooked nose, a gentle stooped face with heavy bags under the eyes
- Одежда: floppy patched felt hat, long patched brown coat, bast shoes with wrapped legs, a walking stick

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: thin old man about 72, long white beard and unkempt white hair, deep-set pale grey eyes, hooked nose, a gentle stooped face with heavy bags under the eyes.
Costume: floppy patched felt hat, long patched brown coat, bast shoes with wrapped legs, a walking stick.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Мальчик · статист

- Эталон из игры: `refs/ref_extra_boy.jpg` (портрет `f15`)
- Лицо: boy about 14, ginger-brown hair under a flat cap, intense light eyes, freckles, a serious face
- Одежда: patched shirt with a red sash, a cloth in his hand

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: boy about 14, ginger-brown hair under a flat cap, intense light eyes, freckles, a serious face.
Costume: patched shirt with a red sash, a cloth in his hand.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```

## Странник · статист

- Эталон из игры: `refs/ref_extra_pilgrim.jpg` (портрет `f16`)
- Лицо: man about 55, long grey-brown hair, long grey beard, calm stern eyes
- Одежда: dark long coat with a wooden cross and prayer beads, a book under the arm

Промпт листа-эталона:

```
Create a wide landscape 3:2 (1536x1024) photographic character reference sheet of the person in the attached game portrait, as a real actor in 1890s rural Russian costume, plain mid-grey studio background, soft even light, no text.
Layout: three head-and-shoulders views on the left (front, three-quarter, profile) and one full-body standing view on the right.
The face must match the attached portrait exactly: man about 55, long grey-brown hair, long grey beard, calm stern eyes.
Costume: dark long coat with a wooden cross and prayer beads, a book under the arm.
Realistic skin with pores and imperfections, tired expression, no glamour, no smile unless described.
```
