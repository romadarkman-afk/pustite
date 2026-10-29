#!/usr/bin/env python3
"""Generate the Russian story and character reactions for «Пустите» with ElevenLabs."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
PROVIDER = "elevenlabs"
MODEL = "eleven_v3"
VOICE_DESIGN_MODEL = "eleven_ttv_v3"
API_ROOT = "https://api.elevenlabs.io/v1"
VOICE_ROOT = Path("game/assets/voice")
VOICE_MAP_PATH = Path("docs/voiceover-voices.json")
MANIFEST_PATH = Path("docs/voiceover-manifest.json")
OUTPUT_FORMAT = "mp3_22050_32"
CHUNK_SIZE = 40
MAX_WORKERS = max(1, min(5, int(os.environ.get("ELEVENLABS_MAX_WORKERS", "3"))))
REQUEST_START_GAP = 0.2
RETRIES = 5
CREDIT_RESERVE = 1.15
VOICE_DESIGN_PREVIEWS = 3
PREVIEW_TEXT = (
    "Вечером деревня стихла. За рекой кто-то медленно позвал по имени, "
    "хотя на берегу никого не было. Староста велел закрыть ставни "
    "и не отвечать до рассвета."
)

BARK_TAGS = {
    "calm": [
        "[soft exhale]", "[sighs]", "[clears throat]", "[pff]",
        "[tsk]", "[coughs]", "[chuckles]", "[yawns]",
    ],
    "fear": [
        "[gasps]", "[heavy breathing]", "[whimpers]", "[shrieks]",
        "[panting]", "[cries]", "[grunts]", "[breathes sharply]",
    ],
    "grief": [
        "[sighs]", "[sobbing]", "[crying]", "[whimpering]",
        "[moans]", "[exhales]", "[heavy breathing]", "[groans]",
    ],
    "rage": [
        "[growls]", "[low growl]", "[angry grunt]", "[grunts]",
        "[hisses]", "[shouts]", "[clears throat]", "[pff]",
    ],
}

VOICE_PRESETS = {
    "m_old": {
        "gender": "male", "age": "older adult, 60-75",
        "description": (
            "Native Russian, standard Russian accent. Male, 60-75. "
            "A weathered village elder and storyteller: grave, restrained and intimate. "
            "Deep chest voice with a slight natural rasp, measured pacing, clear Russian "
            "consonants. Believable human delivery, never a broadcaster."
        ),
    },
    "m_mid": {
        "gender": "male", "age": "middle-aged, 35-50",
        "description": (
            "Native Russian, standard Russian accent. Male, 35-50. "
            "A grounded village craftsman: guarded, tired and quietly alert. "
            "Medium-low voice with a dry, slightly rough timbre, natural conversational pace, "
            "clear Russian diction and no announcer tone."
        ),
    },
    "m_young": {
        "gender": "male", "age": "young adult, 20-30",
        "description": (
            "Native Russian, standard Russian accent. Male, 20-30. "
            "A young traveller under pressure: wary, vulnerable and controlled. "
            "Lighter tenor with natural breath and subtle tension, conversational pacing, "
            "clear Russian diction, believable and not exaggerated."
        ),
    },
    "f_old": {
        "gender": "female", "age": "older adult, 60-75",
        "description": (
            "Native Russian, standard Russian accent. Female, 60-75. "
            "A stern village healer: observant, weary and quietly compassionate. "
            "Mature low-mid voice with a dry, breathy texture, deliberate pacing and natural "
            "Russian articulation; intimate rather than theatrical."
        ),
    },
    "f_mid": {
        "gender": "female", "age": "middle-aged, 35-50",
        "description": (
            "Native Russian, standard Russian accent. Female, 35-50. "
            "A practical village mother: warm, guarded and carrying grief. "
            "Rounded mid-register voice with restrained emotion, natural phrasing and clear "
            "Russian consonants; close, believable speech."
        ),
    },
    "f_young": {
        "gender": "female", "age": "young adult, 20-30",
        "description": (
            "Native Russian, standard Russian accent. Female, 20-30. "
            "A young woman hiding fear: alert, fragile and determined. "
            "Light clear voice with a little breath, understated emotional shifts, natural "
            "conversational pacing and precise Russian diction."
        ),
    },
    "boy": {
        "gender": "male", "age": "young, high-register male voice",
        "description": (
            "Native Russian, standard Russian accent. Young male voice with a naturally high, "
            "youthful register. A quiet village child: curious, cautious and easily startled. "
            "Clear Russian phrasing, restrained energy, human and never cartoonish."
        ),
    },
}

STORY_ACTOR_TYPE = {
    "ignat": "m_old",
    "gordey": "m_mid",
    "efim": "m_mid",
    "melnik": "m_old",
    "smotritel": "m_old",
    "pisar": "m_mid",
}

_rate_lock = threading.Lock()
_next_request_at = 0.0
_temp_root = Path(tempfile.mkdtemp(prefix="pustite-voice-"))


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def api_request(
    api_key: str,
    url: str,
    payload: dict | None = None,
    *,
    method: str = "POST",
    response_type: str = "json",
) -> dict | bytes:
    body = None if method == "GET" else json.dumps(payload or {}, ensure_ascii=False).encode("utf-8")
    last_error = "неизвестная ошибка ElevenLabs"

    for attempt in range(RETRIES):
        wait_for_request_slot()
        request = urllib.request.Request(
            url,
            data=body,
            method=method,
            headers={
                "xi-api-key": api_key,
                "Accept": "audio/mpeg" if response_type == "audio" else "application/json",
                **({"Content-Type": "application/json"} if body is not None else {}),
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=150) as response:
                data = response.read()
            if response_type == "audio":
                if len(data) < 128:
                    raise RuntimeError("ElevenLabs вернул пустой аудиофайл")
                return data
            result = json.loads(data.decode("utf-8"))
            if not isinstance(result, dict):
                raise RuntimeError("ElevenLabs вернул ответ неожиданного формата")
            return result
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            if exc.code == 401:
                raise RuntimeError("ElevenLabs отклонил ELEVENLABS_API_KEY (HTTP 401)") from exc
            if exc.code == 402:
                raise RuntimeError("У аккаунта ElevenLabs недостаточно кредитов (HTTP 402)") from exc
            if exc.code == 403:
                raise RuntimeError("Ключ или тариф ElevenLabs не разрешает операцию (HTTP 403)") from exc
            last_error = f"ElevenLabs HTTP {exc.code}: {details[:400]}"
            if (exc.code == 429 or exc.code >= 500) and attempt + 1 < RETRIES:
                try:
                    delay = float(exc.headers.get("Retry-After", ""))
                except (TypeError, ValueError):
                    delay = min(45.0, 2.0 * (2 ** attempt))
                print(f"::warning::ElevenLabs HTTP {exc.code}; повтор через {delay:.0f} с.")
                time.sleep(delay)
                continue
            break
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = f"Сетевая ошибка ElevenLabs: {type(exc).__name__}"
            if attempt + 1 < RETRIES:
                delay = min(45.0, 2.0 * (2 ** attempt))
                print(f"::warning::{last_error}; повтор через {delay:.0f} с.")
                time.sleep(delay)
                continue
            break
        except Exception as exc:
            last_error = str(exc)
            break

    raise RuntimeError(last_error)


def wait_for_request_slot() -> None:
    global _next_request_at
    with _rate_lock:
        now = time.monotonic()
        wait = max(0.0, _next_request_at - now)
        if wait:
            time.sleep(wait)
        _next_request_at = time.monotonic() + REQUEST_START_GAP


def write_json(path: Path, data: dict) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_voice_map() -> dict:
    path = ROOT / VOICE_MAP_PATH
    state = {}
    if path.is_file():
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            state = {}
    if not isinstance(state, dict) or state.get("provider") != PROVIDER or state.get("model") != MODEL:
        state = {
            "schema_version": 1, "provider": PROVIDER, "model": MODEL,
            "voice_design_model": VOICE_DESIGN_MODEL, "voices": {}, "voice_descriptions": {},
        }
    if not isinstance(state.get("voices"), dict):
        state["voices"] = {}
    if not isinstance(state.get("voice_descriptions"), dict):
        state["voice_descriptions"] = {}
    return state


def fetch_existing_project_voices(api_key: str) -> dict[str, str]:
    response = api_request(api_key, f"{API_ROOT}/voices?page_size=100", method="GET")
    result = {}
    for voice in response.get("voices", []):
        labels = voice.get("labels") or {}
        voice_type = str(labels.get("voice_type", ""))
        voice_id = str(voice.get("voice_id", "")).strip()
        if labels.get("project") == "pustite" and voice_type in VOICE_PRESETS and voice_id:
            result[voice_type] = voice_id
    return result


def estimated_credits(story: list[dict], barks: list[dict], missing_voices: int) -> int:
    speech_chars = sum(
        len(task["text"]) + (len(task["style"]) + 1 if task["style"] else 0)
        for task in story
    )
    bark_chars = sum(len(task["text"]) for task in barks)
    design_chars = len(PREVIEW_TEXT) * VOICE_DESIGN_PREVIEWS * missing_voices
    return math.ceil((speech_chars + bark_chars + design_chars) * CREDIT_RESERVE)


def preflight_subscription(api_key: str, required_credits: int, new_voices: int) -> None:
    subscription = api_request(api_key, f"{API_ROOT}/user/subscription", method="GET")
    try:
        used = int(subscription["character_count"])
        limit = int(subscription["character_limit"])
        used_slots = int(subscription["voice_slots_used"])
        voice_limit = int(subscription["voice_limit"])
    except (KeyError, TypeError, ValueError) as exc:
        raise RuntimeError("Не удалось прочитать лимиты и голосовые слоты аккаунта; генерация остановлена.") from exc

    remaining = max(0, limit - used)
    if remaining < required_credits:
        raise RuntimeError(
            f"Пакету нужно около {required_credits} кредитов с запасом 15%, "
            f"доступно {remaining}. Озвучка не начата."
        )
    if used_slots + new_voices > voice_limit:
        raise RuntimeError(
            f"Нужно {new_voices} новых голосов, свободно {max(0, voice_limit - used_slots)} "
            f"слотов из {voice_limit}. Озвучка не начата."
        )
    max_ops = subscription.get("max_voice_add_edits")
    used_ops = int(subscription.get("voice_add_edit_counter", 0))
    if max_ops is not None and used_ops + new_voices > int(max_ops):
        raise RuntimeError(
            f"Нужно создать {new_voices} голосов, осталось операций "
            f"{max(0, int(max_ops) - used_ops)}. Озвучка не начата."
        )
    print(
        f"Проверка тарифа пройдена: {subscription.get('tier', 'unknown')}, "
        f"доступно {remaining} кредитов, требуется около {required_credits}, "
        f"новых голосов {new_voices}, свободно слотов {max(0, voice_limit - used_slots)}."
    )


def design_voice(api_key: str, voice_type: str, preset: dict) -> str:
    seed = int.from_bytes(hashlib.sha256(voice_type.encode("utf-8")).digest()[:4], "big") % 2147483648
    preview = api_request(
        api_key,
        f"{API_ROOT}/text-to-voice/design",
        {
            "model_id": VOICE_DESIGN_MODEL,
            "voice_description": preset["description"],
            "text": PREVIEW_TEXT,
            "seed": seed,
            "guidance_scale": 5,
            "should_enhance": False,
        },
    )
    previews = preview.get("previews", [])
    if not previews or not previews[0].get("generated_voice_id"):
        raise RuntimeError(f"{voice_type}: ElevenLabs не вернул варианты голоса")
    saved = api_request(
        api_key,
        f"{API_ROOT}/text-to-voice",
        {
            "voice_name": f"Pustite {voice_type}",
            "voice_description": preset["description"],
            "generated_voice_id": previews[0]["generated_voice_id"],
            "labels": {
                "language": "ru", "gender": preset["gender"], "age": preset["age"],
                "project": "pustite", "voice_type": voice_type,
            },
        },
    )
    voice_id = str(saved.get("voice_id", "")).strip()
    if not voice_id:
        raise RuntimeError(f"{voice_type}: ElevenLabs не создал сохранённый голос")
    return voice_id


def resolve_voices(api_key: str, target_branch: str, state: dict) -> dict[str, str]:
    voices = state["voices"]
    descriptions = state["voice_descriptions"]
    for index, (voice_type, preset) in enumerate(VOICE_PRESETS.items(), start=1):
        if str(voices.get(voice_type, "")).strip():
            continue
        voice_id = design_voice(api_key, voice_type, preset)
        voices[voice_type] = voice_id
        descriptions[voice_type] = preset["description"]
        state["created_at_utc"] = state.get("created_at_utc") or dt.datetime.now(dt.timezone.utc).isoformat()
        write_json(VOICE_MAP_PATH, state)
        commit_and_push([VOICE_MAP_PATH], f"save Russian voice {index:02d}", target_branch)
        print(f"[OK] сохранён голосовой профиль {voice_type}")

    selected = dict(voices)
    selected["narrator"] = voices["m_old"]
    if any(not selected.get(key) for key in ["narrator", *VOICE_PRESETS.keys()]):
        raise RuntimeError("В карте ElevenLabs не хватает голосового профиля")
    return selected


def story_style(deck_id: str) -> str:
    if "twist" in deck_id:
        return "[nervously]"
    if "win" in deck_id or "out_" in deck_id:
        return "[sad]"
    if "intro" in deck_id or deck_id == "prologue":
        return "[whispers]"
    return ""


def make_story_tasks(selected_voices: dict[str, str]) -> list[dict]:
    slides = json.loads((ROOT / "game/config/slides.json").read_text(encoding="utf-8"))
    texts = json.loads((ROOT / "game/config/slides_text.json").read_text(encoding="utf-8"))
    ru = texts.get("ru", {})
    tasks = []
    seen = set()
    for deck_id, deck in slides.get("decks", {}).items():
        for panel in deck.get("panels", []):
            for line in panel.get("lines", []):
                key = str(line.get("key", ""))
                parts = key.split(".")
                line_text = ru.get(key, "")
                if len(parts) < 4 or parts[0] != "sl":
                    raise ValueError(f"Некорректный ключ сюжетной строки: {key}")
                if not isinstance(line_text, str) or not line_text.strip():
                    raise ValueError(f"Нет русского текста для сюжетной строки: {key}")
                if key in seen:
                    raise ValueError(f"Повтор ключа сюжетной строки: {key}")
                seen.add(key)
                speaker = str(line.get("who", "")).strip()
                actor_type = STORY_ACTOR_TYPE.get(speaker, "")
                voice = selected_voices.get(actor_type, selected_voices["narrator"])
                if speaker in {"", "guest", "extra_thin", "marina"}:
                    voice = selected_voices["narrator"]
                output = VOICE_ROOT / parts[1] / ("_".join(parts[2:]) + ".ogg")
                tasks.append({
                    "kind": "story", "id": key, "key": key,
                    "speaker": speaker or "narrator", "text": line_text.strip(),
                    "style": story_style(deck_id), "voice": voice, "output": output,
                    "max_seconds": 45.0,
                })
    if not tasks:
        raise ValueError("В slides.json не найдены сюжетные строки.")
    return tasks


def make_bark_tasks(selected_voices: dict[str, str]) -> list[dict]:
    tasks = []
    for voice_type in VOICE_PRESETS:
        for mood, tags in BARK_TAGS.items():
            if len(tags) != 8:
                raise ValueError(f"Для реакции {voice_type}_{mood} требуется ровно 8 вариантов.")
            for index, tag in enumerate(tags):
                output = VOICE_ROOT / "bark" / f"{voice_type}_{mood}_{index}.ogg"
                tasks.append({
                    "kind": "bark", "id": f"{voice_type}_{mood}_{index}",
                    "speaker": voice_type, "mood": mood, "tag": tag, "text": tag,
                    "style": "", "voice": selected_voices[voice_type],
                    "output": output, "max_seconds": 8.0,
                })
    return tasks


def request_audio(api_key: str, task: dict) -> bytes:
    voice_id = urllib.parse.quote(str(task["voice"]), safe="")
    url = f"{API_ROOT}/text-to-speech/{voice_id}?output_format={OUTPUT_FORMAT}"
    text = task["text"]
    if task["kind"] == "story" and task.get("style"):
        text = f"{task['style']} {text}"
    audio = api_request(
        api_key,
        url,
        {"text": text, "model_id": MODEL, "language_code": "ru", "apply_text_normalization": "auto"},
        response_type="audio",
    )
    assert isinstance(audio, bytes)
    return audio


def probe_duration(path: Path) -> float:
    result = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(path),
    ], capture=True)
    return float(result.stdout.strip())


def generate_one(api_key: str, task: dict) -> dict:
    source_path = _temp_root / f"{task['kind']}_{task['id'].replace('.', '_')}.mp3"
    output = ROOT / task["output"]
    output.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_bytes(request_audio(api_key, task))
    try:
        audio_bytes = source_path.read_bytes()
        if not (audio_bytes.startswith(b"ID3") or (
            len(audio_bytes) > 1 and audio_bytes[0] == 0xFF and audio_bytes[1] & 0xE0 == 0xE0
        )):
            raise RuntimeError(f"{task['id']}: ElevenLabs вернул MP3 неверного формата")
        run([
            "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(source_path), "-ac", "1", "-ar", "24000",
            "-c:a", "libvorbis", "-q:a", "5", str(output),
        ])
        duration = probe_duration(output)
        min_duration = 0.10 if task["kind"] == "bark" else 0.20
        if not min_duration <= duration <= task["max_seconds"]:
            output.unlink(missing_ok=True)
            raise RuntimeError(f"{task['id']}: длительность {duration:.2f} с вне допустимого диапазона")
    finally:
        source_path.unlink(missing_ok=True)
    print(f"[OK] {task['id']} -> {task['output']} ({duration:.2f} с)")
    return {"task": task, "duration": duration, "sha256": sha256_file(output)}


def manifest_record(task: dict, duration: float, digest: str) -> dict:
    return {
        "kind": task["kind"], "id": task["id"], "speaker": task["speaker"],
        "file": task["output"].as_posix(), "voice": task["voice"],
        "duration_seconds": round(duration, 2), "sha256": digest,
    }


def read_valid_completed(selected_voices: dict[str, str], tasks: list[dict]) -> dict[str, dict]:
    manifest_file = ROOT / MANIFEST_PATH
    if not manifest_file.is_file():
        return {}
    try:
        state = json.loads(manifest_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if state.get("provider") != PROVIDER or state.get("model") != MODEL or state.get("voices") != selected_voices:
        return {}
    records = {
        str(item.get("id", "")): item
        for item in state.get("files", [])
        if isinstance(item, dict)
    }
    completed = {}
    for task in tasks:
        item = records.get(task["id"])
        path = ROOT / task["output"]
        if not item or not path.is_file() or path.stat().st_size == 0:
            continue
        if item.get("file") != task["output"].as_posix() or item.get("sha256") != sha256_file(path):
            continue
        try:
            duration = float(item.get("duration_seconds", 0.0))
        except (TypeError, ValueError):
            continue
        minimum = 0.10 if task["kind"] == "bark" else 0.20
        if minimum <= duration <= task["max_seconds"]:
            completed[task["id"]] = item
    return completed


def manifest_data(
    story: list[dict], barks: list[dict], selected_voices: dict[str, str],
    tasks: list[dict], completed: dict[str, dict], complete: bool,
) -> dict:
    files = [completed[task["id"]] for task in tasks if task["id"] in completed]
    return {
        "schema_version": 2, "provider": PROVIDER, "model": MODEL,
        "language": "ru-RU", "story_lines": len(story), "bark_clips": len(barks),
        "total_audio_files": len(files), "expected_audio_files": len(tasks),
        "complete": complete and len(files) == len(tasks), "voices": selected_voices,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "files": files,
    }


def commit_and_push(paths: list[Path], label: str, target_branch: str) -> None:
    if paths:
        run(["git", "add", "--", *[path.as_posix() for path in paths]])
    staged = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT, check=False)
    if staged.returncode == 0:
        return
    run(["git", "commit", "-m", f"Add Russian voice pack: {label} [skip ci]"])
    run(["git", "push", "origin", f"HEAD:{target_branch}"])


def self_test() -> int:
    fake_voices = {key: f"test-{key}" for key in VOICE_PRESETS}
    fake_voices["narrator"] = fake_voices["m_old"]
    story = make_story_tasks(fake_voices)
    barks = make_bark_tasks(fake_voices)
    tasks = story + barks
    outputs = [task["output"] for task in tasks]
    errors = []
    if not story or len({task["id"] for task in story}) != len(story):
        errors.append("сюжетные ключи пусты или повторяются")
    if len(outputs) != len(set(outputs)):
        errors.append("два аудиофайла имеют один путь")
    if len(barks) != len(VOICE_PRESETS) * len(BARK_TAGS) * 8:
        errors.append("количество игровых реакций не совпадает с профилями")
    if any(not task["text"].strip() for task in story):
        errors.append("найдена пустая сюжетная реплика")
    if any(not task["text"].startswith("[") or not task["text"].endswith("]") for task in barks):
        errors.append("реакция не оформлена как audio tag ElevenLabs")
    if any(task["voice"] != fake_voices[task["speaker"]] for task in barks):
        errors.append("игровая реакция использует неверный голос")
    if any(not task["output"].as_posix().startswith("game/assets/voice/") for task in tasks):
        errors.append("аудиофайл выводится за пределы каталога озвучки")
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        return 1
    credits = estimated_credits(story, barks, len(VOICE_PRESETS))
    print(f"PASS: {len(story)} сюжетных строк, {len(barks)} реакций, {len(outputs)} уникальных файлов.")
    print(f"Предварительная оценка: около {credits} кредитов с запасом 15%; API не вызывался.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="проверить план без обращения к API")
    args = parser.parse_args()
    if args.self_test:
        return self_test()

    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print("::error title=Нет ключа ElevenLabs::Добавьте ELEVENLABS_API_KEY в GitHub Actions secrets.")
        return 2

    target_branch = os.environ.get("GITHUB_REF_NAME", "main")
    try:
        state = load_voice_map()
        remote_voices = fetch_existing_project_voices(api_key)
        for voice_type, voice_id in remote_voices.items():
            if not state["voices"].get(voice_type):
                state["voices"][voice_type] = voice_id
                state["voice_descriptions"][voice_type] = VOICE_PRESETS[voice_type]["description"]
        fake_voices = {key: key for key in VOICE_PRESETS}
        fake_voices["narrator"] = fake_voices["m_old"]
        story_plan = make_story_tasks(fake_voices)
        bark_plan = make_bark_tasks(fake_voices)
        missing_voices = sum(not state["voices"].get(key) for key in VOICE_PRESETS)
        required_credits = estimated_credits(story_plan, bark_plan, missing_voices)
        preflight_subscription(api_key, required_credits, missing_voices)
        if remote_voices:
            write_json(VOICE_MAP_PATH, state)
            commit_and_push([VOICE_MAP_PATH], "recover saved voice map", target_branch)
        selected_voices = resolve_voices(api_key, target_branch, state)
    except Exception as exc:
        print(f"::error title=Проверка аккаунта или голосов ElevenLabs::{exc}")
        return 1

    story = make_story_tasks(selected_voices)
    barks = make_bark_tasks(selected_voices)
    tasks = story + barks
    completed = read_valid_completed(selected_voices, tasks)
    todo = [task for task in tasks if task["id"] not in completed]
    print(
        f"Пакет: {len(story)} сюжетных строк, {len(barks)} реакций, "
        f"всего {len(tasks)} файлов. Проверено ранее: {len(completed)}, осталось: {len(todo)}."
    )
    print(f"Модель: {MODEL}; параллельно запросов: {MAX_WORKERS}; интервал между запросами: {REQUEST_START_GAP:.1f} с.")

    done = dict(completed)
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        for chunk_start in range(0, len(todo), CHUNK_SIZE):
            chunk = todo[chunk_start:chunk_start + CHUNK_SIZE]
            futures = {pool.submit(generate_one, api_key, task): task for task in chunk}
            results = []
            failures = []
            for future in concurrent.futures.as_completed(futures):
                task = futures[future]
                try:
                    results.append(future.result())
                except Exception as exc:
                    failures.append((task, str(exc)))
                    print(f"::error title=Не создана озвучка::{task['id']}: {exc}")
            if results:
                for result in results:
                    task = result["task"]
                    done[task["id"]] = manifest_record(task, result["duration"], result["sha256"])
                write_json(MANIFEST_PATH, manifest_data(story, barks, selected_voices, tasks, done, False))
                paths = [result["task"]["output"] for result in results] + [MANIFEST_PATH]
                label = f"batch {chunk_start // CHUNK_SIZE + 1:02d}"
                commit_and_push(paths, label, target_branch)
                print(f"Сохранён пакет {label}: {len(results)} файлов.")
            if failures:
                print("::error::Готовые файлы сохранены; повторный запуск продолжит с неполных.")
                return 1

    missing = [task["output"].as_posix() for task in tasks if task["id"] not in done]
    if missing:
        print("::error title=Неполный пакет озвучки::" + ", ".join(missing[:20]))
        return 1
    write_json(MANIFEST_PATH, manifest_data(story, barks, selected_voices, tasks, done, True))
    commit_and_push([MANIFEST_PATH], "coverage manifest", target_branch)
    print(f"[VOICEOVER COMPLETE] {len(story)} сюжетных строк, {len(barks)} реакций; {len(done)} файлов проверены через ffprobe и SHA-256.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
