# Германия и Франция: промпты для рисунков посёлка

В v0.28.0 немецкий и французский языки автоматически выбирают каталоги региональной графики. Нужные папки:

- Германия: game/assets/village/regions/de/
- Франция: game/assets/village/regions/fr/

Для листа зданий приложи house_day.png и house_night.png как референсы стиля. Для земли приложи ground_day.jpg как референс композиции. Создай каждый лист отдельно. Готовые результаты приложи сюда: я разрежу спрайты, удалю фон, подготовлю игровые файлы и соберу обновление.

## Германия: лист зданий

Промпт для Gemini:

> Create one game-art sprite sheet in portrait 3:4 format, arranged as an exact 3-column by 4-row grid of twelve equal square cells. Use the attached house_day.png and house_night.png only as references for the existing game's hand-drawn linework, shading, scale, front three-quarter camera and muted palette.
>
> Setting: a poor rural village in central Germany, late 19th century. Show six separate buildings: a half-timbered home with pale plaster and a steep red-brown tile roof; a timber barn; a small stone village church; a low cellar entrance; a plain wooden cart shed; a small garden shed. Weathered and practical, no modern objects or tourist clichés.
>
> Cell order, left-to-right then top-to-bottom: 1 home_day, 2 home_night, 3 barn_day; 4 barn_night, 5 church_day, 6 church_night; 7 cellar_day, 8 cellar_night, 9 garage_day; 10 garage_night, 11 shed_day, 12 shed_night.
>
> Each day/night pair must have the same silhouette, perspective, scale, details and door location. Night versions keep the same design and add dark blue evening lighting with warm lit windows. Center every building in its cell, show the whole silhouette and leave a clear margin. No cast shadow; the game draws its own ground shadow.
>
> Door center coordinates within each square cell, measured from its top-left corner: home (0.285, 0.75), barn (0.32, 0.75), church (0.295, 0.825), cellar (0.38, 0.465), garage (0.225, 0.68), shed (0.26, 0.625). Keep each complete doorway visible at that position.
>
> Use a flat pure magenta RGB 255,0,255 background in all cells and gaps. No grid lines, borders, labels, text, logos, watermark or object crossing between cells. Keep the grid straight and evenly spaced.

## Германия: земля днём

Промпт для Gemini:

> Create a 4:3 landscape ground background for a mobile village game. Treat the attached ground_day.jpg as a strict composition reference. Keep the camera angle, central square position and size, paths, river, forest edges and open buildable spaces in exactly the same places. Change only natural details to suggest a rural central German village in the late 19th century: temperate meadow grass, deciduous forest, restrained stone edging and muted earth colors. No buildings, people, fences, lamps, wells, furniture, text or signs; the game draws those separately. Match the attached hand-painted dark-outline game art. Keep the center clearing unobstructed. No border or watermark.

## Германия: земля ночью

Используй немецкую землю днём как изображение для редактирования:

> Change only the time of day to a dark blue rural night. Preserve every path, river edge, clearing, forest boundary, open space, camera angle and pixel placement exactly. Add restrained cool moonlight and subtle warm reflected light near the clearing. Do not add buildings, people, lights, signs, text or objects. Keep the hand-painted style and 4:3 framing. No border or watermark.

## Франция: лист зданий

Промпт для Gemini:

> Create one game-art sprite sheet in portrait 3:4 format, arranged as an exact 3-column by 4-row grid of twelve equal square cells. Use the attached house_day.png and house_night.png only as references for the existing game's hand-drawn linework, shading, scale, front three-quarter camera and muted palette.
>
> Setting: a poor rural French village, late 19th century. Show six separate buildings: a modest plastered country home with a steep clay-tile roof and simple shutters; a timber-and-stone barn; a small old stone village church; a low masonry cellar entrance; a plain wooden cart shed; a small weathered garden shed. Use restrained limestone, plaster, dark timber and terracotta colors. No modern objects, Eiffel Tower imagery, tourist styling or ornate châteaux.
>
> Cell order, left-to-right then top-to-bottom: 1 home_day, 2 home_night, 3 barn_day; 4 barn_night, 5 church_day, 6 church_night; 7 cellar_day, 8 cellar_night, 9 garage_day; 10 garage_night, 11 shed_day, 12 shed_night.
>
> Each day/night pair must have the same silhouette, perspective, scale, details and door location. Night versions keep the same design and add dark blue evening lighting with warm lit windows. Center every building in its cell, show the whole silhouette and leave a clear margin. No cast shadow; the game draws its own ground shadow.
>
> Door center coordinates within each square cell, measured from its top-left corner: home (0.285, 0.75), barn (0.32, 0.75), church (0.295, 0.825), cellar (0.38, 0.465), garage (0.225, 0.68), shed (0.26, 0.625). Keep each complete doorway visible at that position.
>
> Use a flat pure magenta RGB 255,0,255 background in all cells and gaps. No grid lines, borders, labels, text, logos, watermark or object crossing between cells. Keep the grid straight and evenly spaced.

## Франция: земля днём

Промпт для Gemini:

> Create a 4:3 landscape ground background for a mobile village game. Treat the attached ground_day.jpg as a strict composition reference. Keep the camera angle, central square position and size, paths, river, forest edges and open buildable spaces in exactly the same places. Change only natural details to suggest a poor rural French village in the late 19th century: temperate meadow grass, mixed deciduous forest, restrained pale stone edging and muted earth colors. No buildings, people, fences, lamps, wells, furniture, text or signs; the game draws those separately. Match the attached hand-painted dark-outline game art. Keep the center clearing unobstructed. No border or watermark.

## Франция: земля ночью

Используй французскую землю днём как изображение для редактирования:

> Change only the time of day to a dark blue rural night. Preserve every path, river edge, clearing, forest boundary, open space, camera angle and pixel placement exactly. Add restrained cool moonlight and subtle warm reflected light near the clearing. Do not add buildings, people, lights, signs, text or objects. Keep the hand-painted style and 4:3 framing. No border or watermark.

## После генерации

Для каждой страны лист зданий содержит 12 спрайтов в указанном порядке. Отдельно нужны ground_day.jpg и ground_night.jpg. Итого 14 файлов для каталога каждого региона. Пока региональный файл отсутствует, игра автоматически берёт соответствующий базовый ресурс.
