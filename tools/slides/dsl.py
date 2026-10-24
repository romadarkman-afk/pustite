"""Мини-язык раскадровок: колода (Deck) состоит из панелей (Panel).

Из одних и тех же данных строятся:
  1. промпты для ChatGPT (docs/slides/*.md);
  2. данные для игры (game/config/slides.json, game/config/slides_text.json).
Править сюжет нужно здесь, а не в готовых файлах.
"""
from __future__ import annotations

from dataclasses import dataclass, field

# --- звуки, которые есть в игре сейчас (game/scripts/autoload/sfx.gd) ---
AMB = {"day": "amb_day", "dusk": "amb_dusk", "night": "amb_night", "river": "amb_river", "wind": "amb_wind",
       "rain": "amb_rain", "blizzard": "amb_blizzard", "murmur": "life_murmur", "mill": "mill_wheel",
       "rails": "rails", "train": "train", "whistle": "whistle", "type": "typewriter", "heart": "heartbeat",
       # новые слои, их ещё нет в игре (TASK-124)
       "fire": "amb_fire", "bog": "amb_bog", "church": "amb_church", "crowd": "amb_crowd"}
MUSIC = {"day": "day", "night": "night", "menu": "menu", "river": "river_theme", "dawn": "end_dawn", "dark": "end_dark",
         # новые темы для комиксов (TASK-123)
         "sad": "theme_sad", "hope": "theme_hope", "tense": "theme_tense", "grief": "theme_grief"}
FX = {"knock", "door_open", "door_shut", "bell", "scratch", "whisper", "roof_steps", "creak", "cry_far", "human_cry_m",
      "human_cry_f", "upyr_cry", "growl", "breath", "breath_2", "breath_3", "gasp", "call_far", "scare", "weep", "death",
      "latch", "floorboard", "cup_break", "hammer", "dawn", "win", "lose", "reveal", "reveal_2", "reveal_3", "exile",
      "life_dog", "life_hens", "tap", "tick", "job_done", "job_fail",
      # новые, ещё не записаны (TASK-124)
      "wolf", "crow", "fire_crackle", "water_drip", "steps_snow", "chain", "match", "page", "glass", "wind_gust"}
NEW_AMB = {"amb_fire", "amb_bog", "amb_church", "amb_crowd"}
NEW_MUSIC = {"theme_sad", "theme_hope", "theme_tense", "theme_grief"}
NEW_FX = {"wolf", "crow", "fire_crackle", "water_drip", "steps_snow", "chain", "match", "page", "glass", "wind_gust"}


def S(amb: str | None = None, music: str | None = None, fx=(), silence: bool = False, stop_amb: bool = False,
      stop_music: bool = False, fade: float = 1.4) -> list[dict]:
    """Звуковая карта панели в формате Scenes (start/stop/play/silence).
    amb, music: ключи из AMB и MUSIC; fx: [(имя, задержка_с, громкость_дБ), ...]; пустая карта значит «без изменений»."""
    ev: list[dict] = []
    if silence:
        ev.append({"at": 0.0, "do": "silence", "fade": 0.6})
    if stop_amb:
        ev.append({"at": 0.0, "do": "stop", "layer": "amb", "fade": fade})
    if stop_music:
        ev.append({"at": 0.0, "do": "stop", "layer": "music", "fade": fade})
    if amb:
        ev.append({"at": 0.0, "do": "start", "layer": "amb", "id": AMB[amb], "fade": fade})
    if music:
        ev.append({"at": 0.0, "do": "start", "layer": "music", "id": MUSIC[music], "fade": fade + 0.8})
    for item in fx:
        name, at, vol = (item + (-6.0,))[:3] if len(item) == 2 else item
        if name not in FX:
            raise ValueError(f"нет звука {name}")
        ev.append({"at": float(at), "do": "play", "id": name, "vol": float(vol)})
    ev.sort(key=lambda e: e["at"])
    return ev


def N(text: str) -> tuple[str, str]:
    """Закадровый текст героя (от первого лица, настоящее время, без рода глагола)."""
    return ("", text)


def D(who: str, text: str) -> tuple[str, str]:
    """Реплика персонажа; who: id из CAST или короткое имя вроде «Голос»."""
    return (who, text)


@dataclass
class Panel:
    sz: str                    # "t" высокая 1024x1536, "w" широкая 1536x1024
    shot: str                  # план и ракурс, по-английски
    en: str                    # что в кадре, по-английски
    cap: list                  # подписи: [N(...), D(...)]
    snd: list = field(default_factory=list)
    cast: tuple = ()
    tier: str = "B"            # A: первая волна, B: вторая
    cam: str = ""              # движение камеры: zoom_in, zoom_out, pan_l, pan_r, pan_u, pan_d, shake, hold
    key: str = ""              # номер внутри колоды, заполняется Deck


@dataclass
class Deck:
    id: str
    ru: str                    # название по-русски
    kind: str                  # prologue | act_intro | act_outro | ch_intro | ch_win | ch_twist | bio | guest | npc | finale
    when: str                  # когда показывается в игре
    grade: str                 # цвет и свет колоды, по-английски
    mood: str                  # настроение и музыка, по-русски
    panels: list = field(default_factory=list)
    music: str = ""            # музыка колоды по умолчанию (ключ MUSIC)
    flash: bool = False        # воспоминание: выцветшая плёнка

    def add(self, sz, shot, en, cap, snd=None, cast=(), tier="B", cam=""):
        p = Panel(sz, shot, en, cap, snd or [], tuple(cast), tier, cam, "%02d" % (len(self.panels) + 1))
        self.panels.append(p)
        return p


DECKS: list[Deck] = []


def deck(id, ru, kind, when, grade, mood, music="", flash=False) -> Deck:
    d = Deck(id, ru, kind, when, grade, mood, [], music, flash)
    DECKS.append(d)
    return d
