# Картинки для погоды и сезонов: что рисовать и как

Движок сам двигает и накладывает эффекты: облака плывут шейдером, трава качается шейдером, снег идёт частицами и ложится на землю шейдером, дождь бьёт в землю брызгами. Для этого ему нужны фотореалистичные картинки. Ниже промпты для ChatGPT. Пока картинок нет, в игре стоят заглушки с теми же именами файлов (их делает `tools/make_weather_placeholders.py`). Готовый файл ложится на место заглушки, код менять не надо.

## Как работать

1. Откройте новый чат в ChatGPT, вставьте промпт и (где написано) приложите файл-образец.
2. Фон ChatGPT не делает прозрачным, поэтому в каждом промпте указан однотонный фон: чёрный для светлых и светящихся вещей, зелёный `#00FF00` или пурпурный `#FF00FF` для цветных. Это нужно, чтобы скрипт вырезал фон сам.
3. Спрайты можно рисовать в любом порядке и с любыми промежутками. Скрипт `tools/make_atlas.py` найдёт каждый спрайт и соберёт ровный атлас. Главное: между спрайтами видна полоса фона и спрайты не касаются друг друга.
4. Сырые картинки пришлите мне в этот чат, я обработаю и залью. Если ChatGPT нарисовал меньше спрайтов, чем нужно, скрипт повторит имеющиеся, игре это не мешает.

Общая приписка к каждому промпту (уже вставлена ниже): `Photorealistic, gritty, desaturated, cold natural light, 1890s rural Russia, cinematic still, no text, no logos, no borders, no watermark.`

## Волна 1. Земля по сезонам (самое заметное)

Сейчас земля всех карт нарисована в одной зелёно-бурой гамме, зимней нет совсем. Во всех трёх промптах ChatGPT получает текущий файл и перерисовывает только сезон. Дома в игре ставятся поверх по координатам, поэтому композиция не должна сдвинуться ни на пиксель.

Файлы-образцы лежат в `game/assets/village/realistic/` (я пришлю их в чат по запросу).

| Карта | Акт | Сезон | Что приложить | Куда положить |
|---|---|---|---|---|
| Мельница | II | поздняя осень | `ground_mill_day.jpg`, `ground_mill_night.jpg` | те же имена |
| Монастырь | III | глубокая зима | `ground_monastery_day.jpg`, `ground_monastery_night.jpg`, `ground_monastery_night_lunar.png` | те же имена |
| Станция | IV | ранняя весна, оттепель | `ground_station_day.jpg`, `ground_station_night.jpg` | те же имена |
| Деревня | I | лето, остаётся как есть | не нужно | |

Общая часть промпта (в начало каждого):

```
Edit the attached image. Keep EXACTLY the same composition, camera angle, framing, image size and aspect ratio. Keep the stone circle, paths, fence, river, rails and tree line in exactly the same places and the same perspective. Nothing may move, because game objects are placed on top by coordinates. Do not add buildings, people, animals, text or objects. Change only the season and the weather look of the ground, grass, water and trees. Photorealistic, gritty, desaturated, cold natural light, 1890s rural Russia, cinematic still.
```

Дальше по карте:

**Мельница, день (осень).**
```
Season: late autumn, after days of rain. Wet rust-brown and ochre fallen leaves on the ground and in the grass, wet dark mud, grey puddles reflecting an overcast sky, brown dead reeds along the river, a few bare birches, heavy grey sky reflected in the water. Cold, damp, no snow.
```
**Мельница, ночь.** Приложить ночной файл и добавить: `Same autumn changes, but keep the existing night lighting: deep blue moonlit night, wet leaves and puddles catching faint moonlight.`

**Монастырь, день (зима).**
```
Season: deep winter. Knee-deep fresh snow over the whole yard, snow on the stone circle with the stones barely showing, trampled dark footpaths, frozen puddles, thick frost and icicles on the fence, bare branches heavy with snow, snow drifts against the wall. Overcast pale sky light, cold blue-white tones.
```
**Монастырь, ночь и лунная ночь.** Приложить ночные файлы и добавить: `Same deep winter snow, but keep the existing night lighting: snow glows blue under moonlight, long soft shadows, ice glitters faintly.`

**Станция, день (весна).**
```
Season: early spring thaw. Dirty grey patches of melting snow between wet black soil, brown mud, large puddles on the gravel and between the rails, first pale green shoots in the grass, wet shiny rails and sleepers, thin mist near the ground. Overcast soft light, cool tones.
```
**Станция, ночь.** Приложить ночной файл и добавить: `Same thaw season, keep the existing night lighting: cold blue night, puddles reflect faint light, wet rails shine.`

Проверка результата: наложить на оригинал, края деревьев, рельсы и каменный круг должны совпасть. Если сдвинулось, просите ChatGPT повторить и прикладывайте оригинал ещё раз.

## Волна 2. Спрайты эффектов

Размеры и сетки указаны для атласа, который соберёт скрипт. Ваша картинка может быть любого размера, например 2048 px по длинной стороне.

### Облака: `clouds.png`, полоса 2048×512, бесшовная по горизонтали
Одна полоса на все времена суток: днём она белая, в сумерках оранжевая, ночью тёмно-синяя (цвет задаёт шейдер).
```
A wide panoramic strip of photorealistic clouds for a sky layer, 4:1 aspect ratio, soft layered stratocumulus and thin streaky altostratus, pure white and light grey clouds with soft edges, on a flat pure black background (#000000). The left and right edges must continue each other seamlessly so the strip can repeat. Clouds fill the middle band, the top and bottom edges fade fully to black. Photorealistic, no text.
```
Команда: `python3 tools/make_atlas.py strip raw/clouds.png game/assets/weather/clouds.png --size 2048x512 --key black`

### Снежинки: `flake_sheet.png`, атлас 4×4 по 128 px
```
A sheet of 16 different photorealistic snowflakes and small snow clumps, macro photography, various sizes and shapes: crystal stars, soft fluffy clumps, tiny grains, slightly motion-blurred ones. Pure white and pale blue-white, soft edges, evenly spaced with clear black gaps between them, on a flat pure black background (#000000). Each flake fully separate, none touching. No text.
```
`python3 tools/make_atlas.py sheet raw/flakes.png game/assets/weather/flake_sheet.png --grid 4x4 --cell 128 --key black`

### Капли дождя: `rain_sheet.png`, атлас 4×1 по 128 px
```
4 different photorealistic rain streaks, each one a thin vertical motion-blurred raindrop trail, brighter and sharper at the bottom end, fading to transparent at the top, silvery translucent, various lengths and thickness. Evenly spaced in a row with wide black gaps, on a flat pure black background (#000000). No text.
```
`... --grid 4x1 --cell 128 --key black`

### Брызги: `splash_sheet.png`, атлас 4×2 по 128 px (8 кадров анимации)
Кадры идут по порядку: от удара капли до исчезновения.
```
A sequence of 8 frames of a single raindrop splash on wet ground, photorealistic macro, slightly top-down three-quarter view: frame 1 tiny impact, frames 2-4 water crown growing, frames 5-8 crown breaking into small droplets and fading. Bright translucent white-blue water on a flat pure black background (#000000), arranged in two rows of four in order, clear gaps between frames. No text.
```
`... --grid 4x2 --cell 128 --key black`

### Рябь: `ripple_sheet.png`, атлас 4×2 по 128 px (8 кадров)
```
A sequence of 8 frames of a water ripple spreading on a puddle, viewed from a low three-quarter angle so rings look like thin ellipses: frame 1 a small ring, each next frame larger and fainter, last frame almost invisible. Bright pale-blue rings on a flat pure black background (#000000), two rows of four in order, clear gaps. Photorealistic, no text.
```
`... --grid 4x2 --cell 128 --key black`

### Осенние листья: `leaf_sheet.png`, атлас 4×2 по 128 px
```
8 different photorealistic fallen autumn leaves seen from above, slightly curled: yellow birch, orange-red aspen, brown oak, dark red maple, one half-dried and torn. Natural colors with fine veins and a bit of wet shine, evenly spaced with wide gaps, on a flat pure bright green background (#00FF00). The leaves themselves must not contain green. No text.
```
`... --grid 4x2 --cell 128 --key green`

### Тополиный пух: `fluff_sheet.png`, атлас 4×2 по 64 px
```
8 different photorealistic poplar fluff tufts, soft white airy cotton-like seed fluff with a tiny dark seed in some, delicate fibres, translucent edges, macro photography, evenly spaced with wide gaps on a flat pure black background (#000000). No text.
```
`... --grid 4x2 --cell 64 --key black`

### Тлеющий пепел: `ember_sheet.png`, атлас 4×2 по 64 px
```
8 different photorealistic glowing ash and ember specks flying in the air: tiny orange-red hot sparks, small glowing flakes of burning peat ash with a dark charred core and a soft orange glow, varied sizes. Evenly spaced with wide gaps on a flat pure black background (#000000). No text.
```
`... --grid 4x2 --cell 64 --key black`

### Туман: `mist_sheet.png`, атлас 2×2 по 512 px
```
4 different large soft billows of ground fog, photorealistic, grey-white translucent vapour with soft feathered edges that fade completely to black, no hard edges, each one a separate cloud of mist, evenly spaced on a flat pure black background (#000000). No text.
```
`... --grid 2x2 --cell 512 --key black`

### Трава: `grass_green_sheet.png` и `grass_dry_sheet.png`, атласы 4×2 по 256 px
Это пучки, которые движок расставит по краям поля и качнёт ветром. Низ пучка должен стоять ровно на нижней кромке спрайта.
```
8 different photorealistic grass tufts seen from a low three-quarter angle, each growing from the bottom edge of its own cell: wild meadow grass, taller blades, some with seed heads, dandelion leaves, reed-like stalks, natural dew. Varied heights from low to tall. Evenly spaced with wide gaps on a flat pure magenta background (#FF00FF). The grass must not contain magenta or pink. No text.
```
Для сухой версии заменить описание на: `dry late-autumn grass, straw yellow and brown, bent and tangled, with dead seed heads`.
`... --grid 4x2 --cell 256 --key magenta`

### Снег для земли: `snow_ground.jpg`, плитка 1024×1024, бесшовная
Шейдер по этой текстуре кладёт снег на землю любой карты: чем больше снега в главе, тем больше его видно.
```
A seamless tileable texture of fresh snow on the ground seen from directly above, photorealistic: fine grains, small soft wind ripples, subtle blue shadows, a few tiny footprints and twig marks, evenly lit with no strong shadows, no horizon, no objects, uniform tone so it repeats without visible seams, 1:1 aspect ratio.
```
`python3 tools/make_atlas.py tile raw/snow.png game/assets/weather/snow_ground.jpg --size 1024x1024`

## Волна 3 (по желанию, позже)

* Зимние версии домов: крыши в снегу для `house`, `barn`, `church`, `shed`, `garage`, `cellar`, день и ночь, 12 файлов, тот же размер и положение двери, что у оригиналов.
* Новые жители для выбора образа: 8 заметно разных силуэтов (высокий, коренастый, ребёнок, старик с палкой, женщина с коромыслом, священник, солдат, торговец с мешком). Сейчас образа похожи друг на друга по росту и одежде. Приложить два текущих образа как образец стиля и размера.

## Куда что кладётся

| Файл | Папка |
|---|---|
| ground_*.jpg / png | `game/assets/village/realistic/` |
| clouds.png, *_sheet.png, snow_ground.jpg | `game/assets/weather/` |
