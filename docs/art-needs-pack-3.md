# Что нужно от Влади по картинкам (пакет 3)

Код готов и работает без этих файлов. Каждый файл кладётся на своё место с точным именем, код менять не надо.

## TASK-076. Портреты с закрытыми глазами

Игра уже умеет моргать: раз в 3–6 секунд на 0,12 с подставляет вторую картинку. Пока файлов нет, моргания нет, остальное (дыхание, дрожь, наклон, затемнение лжеца) работает.

- Взять оригинал жителя из `game/assets/folk/realistic/` (`f1.png` … `f16.png`).
- Отредактировать только глаза: закрыть веки. Всё остальное пиксель в пиксель, тот же размер, тот же фон.
- Сохранить рядом с оригиналом с суффиксом `_blink`: `f1_blink.png`, `f2_blink.png` и так далее.
- Нужно минимум 12 основных жителей (`f1` … `f12`). Остальные можно позже. Гостей кампании и героя можно оставить без моргания.

Промпт для редактирования оригинала (картинка прикладывается):

```
Edit this exact image: close the person's eyes (eyelids shut, relaxed, no smile change). Change nothing else: same pose, same clothes, same lighting, same background, same size and framing. Photorealistic, no text, no watermark.
```

Проверка: наложить оригинал и копию в графическом редакторе, отличаться должна только область глаз.

## TASK-077. Силуэт тени за окном

Тень проходит мимо двери слева направо раз за ночь, со второй ночи. Пока файла нет, идёт тёмное мягкое пятно.

- Файл: `game/assets/ui/window_shadow.png`, PNG с прозрачным фоном, около 256×512.
- Тёмный силуэт человека в профиль, идущего вдоль стены, мягкие размытые края, без деталей лица. Почти чёрный, прозрачность внутри 80–90%.
- Игра сама растягивает картинку по высоте двери (420 единиц) и двигает по экрану, поэтому фигура должна быть по центру кадра.

Промпт:

```
A dark soft silhouette of a person walking past a window at night, side profile, cloaked, head slightly bowed, blurred edges, no facial details, isolated on a transparent background, no ground, no text. Photorealistic shadow, near black.
```

## TASK-079. Открытая дверь дома изгнанного

Пока файла нет, дверь рисуется кодом: тёмный проём и светлая кромка створки. Дверь качается на ветру и раз в 6–11 с скрипит.

- Файл: `game/assets/village/realistic/door_ajar.png`, PNG с прозрачным фоном, ориентир 120×200 (тот же ракурс сверху-сбоку, что у домов).
- Картинка ложится на дверь любого дома и тянется по ширине двери ±12% (качание). Проём тёмный почти до чёрного, створка приоткрыта примерно на треть ширины, у края видна толщина доски и петля. Вне двери ничего нет: стену, крыльцо и соседние доски не рисовать.
- Дом может быть отражён: игра зеркалит картинку сама.

Промпт:

```
A wooden plank house door ajar by about a third, seen from a high three-quarter angle, dark empty interior visible through the gap, weathered grey boards, iron hinge, slight shadow on the leaf. Isolated on a transparent background, no wall, no steps, no ground, no text. Photorealistic, gritty, desaturated, 1890s rural Russia.
```

## TASK-086. Финал «открыть дверь»

Сцена `final_shore` показывается, когда игрок открывает дверь тому, кто звал с того берега. Пока файла нет, под текстом идёт картинка двери из `final_door.png`.

- Файл: `game/assets/scenes/final_shore.jpg` (или `.png`), вертикальный кадр как у остальных сцен, ориентир 1080×1920. Код возьмёт файл сам.
- За открытой дверью светлее, чем в доме: рассветный туман над водой, дальний берег, на пороге лежит полоса света. Людей и лиц нет.

Промпт:

```
View from inside a dark wooden peasant house through an open door onto a misty river shore at first light, pale warm glow beyond the threshold, calm water, far bank barely visible, a band of light falling across the plank floor. Vertical composition, no people, no text. Photorealistic, gritty, desaturated, cold natural light, 1890s rural Russia, cinematic still.
```
