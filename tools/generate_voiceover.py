#!/usr/bin/env python3
"""Build the Russian voice pack used by the slide player and village bark system."""

from __future__ import annotations

import base64
import concurrent.futures
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
MODEL = "gemini-3.8-flash-tts"
API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
VOICES_URL = "https://generativelanguage.googleapis.com/v1beta/voices?page_size=1000"
VOICE_ROOT = Path("game/assets/voice")
MANIFEST_PATH = Path("docs/voiceover-manifest.json")
PILOT_PATH = Path("game/assets/voice/a1c1_intro/03_0.ogg")
PILOT_OLD_BLOB_SHA = "3aee3102ce11f0f4dc6691f918c3a82efb98ccab"
CHUNK_SIZE = 20
MAX_WORKERS = 2
REQUEST_START_GAP = 4.0
RETRIES = 5

BARK_TAGS = {
    "calm": [
        "<breath>", "<sigh>", "<throat-clearing>", "<pff>",
        "<tsk>", "<cough>", "<chuckle>", "<yawn>",
    ],
    "fear": [
        "<gasp>", "<heavy breath>", "<whimper>", "<shriek>",
        "<pant>", "<cry>", "<grunt>", "<breath>",
    ],
    "grief": [
        "<sigh>", "<sob>", "<cry>", "<whimper>",
        "<moan>", "<exhales>", "<heavy breath>", "<groan>",
    ],
    "rage": [
        "<grr>", "<growl>", "<argh>", "<grunt>",
        "<hiss>", "<shout>", "<throat-clearing>", "<pff>",
    ],
}

VOICE_PRESETS = {
    "m_old": {"gender": "male", "pitch": "low", "preferred": ["Gacrux", "Algenib", "Charon"]},
    "m_mid": {"gender": "male", "pitch": "medium", "preferred": ["Algenib", "Orus", "Charon"]},
    "m_young": {"gender": "male", "pitch": "high", "preferred": ["Fenrir", "Puck", "Zubenelgenubi"]},
    "f_old": {"gender": "female", "pitch": "low", "preferred": ["Sulafat", "Gacrux", "Aoede"]},
    "f_mid": {"gender": "female", "pitch": "medium", "preferred": ["Vindemiatrix", "Aoede", "Callirrhoe"]},
    "f_young": {"gender": "female", "pitch": "high", "preferred": ["Leda", "Zephyr", "Laomedeia"]},
    "boy": {"gender": "male", "pitch": "high", "preferred": ["Puck", "Fenrir", "Leda"]},
}

STORY_ACTOR_TYPE = {
    "ignat": "m_old",
    "gordey": "m_mid",
    "efim": "m_mid",
    "melnik": "m_old",
    "smotritel": "m_old",
    "pisar": "m_mid",
}

BARK_STYLE = {
    "calm": "A quiet natural human backchannel, restrained and brief, with no spoken words.",
    "fear": "A brief startled human reaction, frightened and breath-close, restrained, with no spoken words.",
    "grief": "A short human reaction of held-back sorrow, tired and broken, with no spoken words.",
    "rage": "A short contained angry human reaction, low and tense, with no spoken words.",
}

_rate_lock = threading.Lock()
_next_request_at = 0.0
_temp_root = Path(tempfile.mkdtemp(prefix="pustite-voice-"))


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def git_blob_sha(path: Path) -> str:
    result = subprocess.run(
        ["git", "rev-parse", f"HEAD:{path.as_posix()}"],
        cwd=ROOT,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def fetch_voice_catalog(api_key: str) -> list[dict]:
    request = urllib.request.Request(VOICES_URL, headers={"x-goog-api-key": api_key})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            data = json.loads(response.read())
        voices = data.get("voices", [])
        print(f"Каталог голосов Gemini: найдено {len(voices)} голосов.")
        return voices if isinstance(voices, list) else []
    except Exception as exc:
        print(f"::warning::Не удалось прочитать каталог голосов Gemini ({type(exc).__name__}); используются встроенные имена.")
        return []


def voice_identity(item: dict) -> str:
    return str(item.get("id") or item.get("display_name") or item.get("displayName") or "")


def voice_name(item: dict) -> str:
    return str(item.get("display_name") or item.get("displayName") or item.get("id") or "")


def find_catalog_voice(catalog: list[dict], preferred: list[str], gender: str = "") -> str:
    for wanted in preferred:
        for item in catalog:
            names = {
                str(item.get("id", "")).casefold(),
                str(item.get("display_name", item.get("displayName", ""))).casefold(),
            }
            if wanted.casefold() not in names:
                continue
            actual_gender = str(item.get("gender", "")).casefold()
            if gender and actual_gender and actual_gender != gender:
                continue
            return voice_identity(item) or wanted

    candidates = []
    for item in catalog:
        actual_gender = str(item.get("gender", "")).casefold()
        if gender and actual_gender != gender:
            continue
        candidates.append(item)
    if candidates:
        target_pitch = ""
        for wanted in preferred:
            if wanted.casefold() in {"gacrux", "sulafat"}:
                target_pitch = "low"
            elif wanted.casefold() in {"leda", "fenrir", "puck", "zephyr"}:
                target_pitch = "high"
        if target_pitch:
            for item in candidates:
                if str(item.get("pitch", "")).casefold() == target_pitch:
                    return voice_identity(item) or voice_name(item)
        return voice_identity(candidates[0]) or voice_name(candidates[0])
    return preferred[0]


def resolve_voices(catalog: list[dict]) -> dict[str, str]:
    catalog_names = {
        str(item.get("display_name", item.get("displayName", ""))).casefold()
        for item in catalog
    }
    if any(name == "bodi" for name in catalog_names):
        narrator = find_catalog_voice(catalog, ["Bodi"])
        print("Для рассказчика выбран голос Bodi из проекта Gemini.")
    else:
        narrator = find_catalog_voice(catalog, ["Vindemiatrix", "Gacrux"])
        print(f"Голос Bodi в каталоге проекта не найден; рассказчик использует {narrator}.")

    selected = {"narrator": narrator}
    for voice_type, preset in VOICE_PRESETS.items():
        selected[voice_type] = find_catalog_voice(
            catalog,
            list(preset["preferred"]),
            str(preset["gender"]),
        )
    return selected


def story_style(deck_id: str, speaker: str) -> str:
    if speaker:
        if "twist" in deck_id:
            mood = "with a restrained edge of fear and a slight hesitation on the reveal"
        elif "win" in deck_id or "out_" in deck_id:
            mood = "tired and relieved, with grief kept under control"
        else:
            mood = "quietly urgent and emotionally contained"
        return f"Natural Russian character dialogue, intimate folk-horror performance, {mood}; clear diction, no announcer cadence, no added words."
    if "twist" in deck_id:
        mood = "growing unease, held breath, and a subdued edge of fear"
    elif "win" in deck_id or "out_" in deck_id:
        mood = "weary relief with grief held back"
    elif "intro" in deck_id or deck_id == "prologue":
        mood = "measured and intimate, with quiet foreboding"
    else:
        mood = "calm and close, with low-key suspense"
    return f"Russian dark folk-horror narration, {mood}; natural literary cadence, clear diction, no broadcaster tone, no added words."


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
                text = ru.get(key, "")
                if len(parts) < 4 or parts[0] != "sl":
                    raise ValueError(f"Некорректный ключ сюжетной строки: {key}")
                if not isinstance(text, str) or not text.strip():
                    raise ValueError(f"Нет русского текста для сюжетной строки: {key}")
                if key in seen:
                    raise ValueError(f"Повтор ключа сюжетной строки: {key}")
                seen.add(key)

                speaker = str(line.get("who", "")).strip()
                actor_type = STORY_ACTOR_TYPE.get(speaker, "")
                voice = selected_voices.get(actor_type, selected_voices["narrator"])
                if speaker == "marina":
                    voice = selected_voices["narrator"]
                if speaker in {"", "guest", "extra_thin"}:
                    voice = selected_voices["narrator"]

                output = VOICE_ROOT / parts[1] / ("_".join(parts[2:]) + ".ogg")
                tasks.append({
                    "kind": "story",
                    "id": key,
                    "key": key,
                    "speaker": speaker or "narrator",
                    "text": text.strip(),
                    "voice": voice,
                    "style": story_style(deck_id, speaker),
                    "output": output,
                    "max_seconds": 45.0,
                })

    if len(tasks) < 1:
        raise ValueError("В slides.json не найдены сюжетные строки.")
    return tasks


def make_bark_tasks(selected_voices: dict[str, str]) -> list[dict]:
    tasks = []
    for voice_type, preset in VOICE_PRESETS.items():
        for mood, tags in BARK_TAGS.items():
            if len(tags) != 8:
                raise ValueError(f"Для реакции {voice_type}_{mood} требуется ровно 8 вариантов.")
            for index, tag in enumerate(tags):
                output = VOICE_ROOT / "bark" / f"{voice_type}_{mood}_{index}.ogg"
                tasks.append({
                    "kind": "bark",
                    "id": f"{voice_type}_{mood}_{index}",
                    "speaker": voice_type,
                    "mood": mood,
                    "tag": tag,
                    "text": tag,
                    "voice": selected_voices[voice_type],
                    "style": BARK_STYLE[mood],
                    "output": output,
                    "max_seconds": 8.0,
                })
    return tasks


def wait_for_request_slot() -> None:
    global _next_request_at
    with _rate_lock:
        now = time.monotonic()
        wait = max(0.0, _next_request_at - now)
        if wait:
            time.sleep(wait)
        _next_request_at = time.monotonic() + REQUEST_START_GAP


def request_audio(api_key: str, task: dict) -> bytes:
    payload = {
        "contents": [{
            "role": "user",
            "parts": [{
                "text": task["text"],
                "speech_metadata": {"style": task["style"]},
            }],
        }],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "languageCode": "ru-RU",
                "voiceConfig": {"voice": task["voice"]},
            },
        },
    }
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    last_error = "неизвестная ошибка Gemini"

    for attempt in range(RETRIES):
        wait_for_request_slot()
        request = urllib.request.Request(
            API_URL,
            data=body,
            method="POST",
            headers={
                "x-goog-api-key": api_key,
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=150) as response:
                result = json.loads(response.read())
            error = result.get("error")
            if error:
                raise RuntimeError(str(error.get("message", "Gemini вернул ошибку")))
            parts = []
            for candidate in result.get("candidates", []):
                content = candidate.get("content", {})
                for part in content.get("parts", []):
                    inline = part.get("inlineData", part.get("inline_data", {}))
                    if inline.get("data"):
                        parts.append(inline["data"])
            if not parts:
                raise RuntimeError("Gemini не вернул аудиоданные")
            return base64.b64decode(parts[0], validate=True)
        except urllib.error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            last_error = f"Gemini HTTP {exc.code}: {details[:500]}"
            daily_limit = any(token in details.casefold() for token in ("perday", "per day", "requestsperday"))
            if exc.code == 429 and not daily_limit and attempt + 1 < RETRIES:
                retry_header = exc.headers.get("Retry-After", "")
                delay = float(retry_header) if retry_header.isdigit() else min(60.0, 10.0 * (2 ** attempt))
                print(f"::warning::Gemini ограничил частоту; повтор через {delay:.0f} с.")
                time.sleep(delay)
                continue
            if exc.code >= 500 and attempt + 1 < RETRIES:
                delay = min(60.0, 5.0 * (2 ** attempt))
                print(f"::warning::Временный сбой Gemini HTTP {exc.code}; повтор через {delay:.0f} с.")
                time.sleep(delay)
                continue
            break
        except (urllib.error.URLError, TimeoutError) as exc:
            last_error = f"Сетевая ошибка Gemini: {type(exc).__name__}"
            if attempt + 1 < RETRIES:
                delay = min(60.0, 5.0 * (2 ** attempt))
                print(f"::warning::{last_error}; повтор через {delay:.0f} с.")
                time.sleep(delay)
                continue
            break
        except Exception as exc:
            last_error = str(exc)
            break

    raise RuntimeError(f"{task['id']}: {last_error}")


def probe_duration(path: Path) -> float:
    result = run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(path),
    ], capture=True)
    return float(result.stdout.strip())


def generate_one(api_key: str, task: dict) -> dict:
    wav_path = _temp_root / f"{task['kind']}_{task['id'].replace('.', '_')}.wav"
    output = ROOT / task["output"]
    output.parent.mkdir(parents=True, exist_ok=True)
    wav = request_audio(api_key, task)
    if len(wav) < 44 or wav[:4] != b"RIFF" or wav[8:12] != b"WAVE":
        raise RuntimeError(f"{task['id']}: Gemini вернул WAV неверного формата")
    wav_path.write_bytes(wav)
    run([
        "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(wav_path), "-ac", "1", "-ar", "24000",
        "-c:a", "libvorbis", "-q:a", "5", str(output),
    ])
    duration = probe_duration(output)
    min_duration = 0.10 if task["kind"] == "bark" else 0.20
    if not min_duration <= duration <= task["max_seconds"]:
        output.unlink(missing_ok=True)
        raise RuntimeError(f"{task['id']}: длительность {duration:.2f} с вне допустимого диапазона")
    wav_path.unlink(missing_ok=True)
    print(f"[OK] {task['id']} -> {task['output']} ({duration:.2f} с)")
    return {
        "task": task,
        "duration": duration,
    }


def commit_and_push(paths: list[Path], label: str, target_branch: str) -> None:
    if paths:
        run(["git", "add", "--", *[path.as_posix() for path in paths]])
    staged = subprocess.run(
        ["git", "diff", "--cached", "--quiet"],
        cwd=ROOT,
        check=False,
    )
    if staged.returncode == 0:
        return
    run(["git", "commit", "-m", f"Add Russian voice pack: {label} [skip ci]"])
    run(["git", "push", "origin", f"HEAD:{target_branch}"])


def main() -> int:
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("::error title=Нет ключа Gemini::Добавьте GEMINI_API_KEY в GitHub Actions secrets.")
        return 2

    catalog = fetch_voice_catalog(api_key)
    selected_voices = resolve_voices(catalog)
    story = make_story_tasks(selected_voices)
    barks = make_bark_tasks(selected_voices)
    tasks = story + barks

    old_pilot = git_blob_sha(PILOT_PATH) == PILOT_OLD_BLOB_SHA
    todo = []
    skipped = 0
    for task in tasks:
        local_path = ROOT / task["output"]
        if task["output"] == PILOT_PATH and old_pilot:
            todo.append(task)
        elif local_path.is_file() and local_path.stat().st_size > 0:
            skipped += 1
        else:
            todo.append(task)

    print(
        f"Пакет: {len(story)} сюжетных строк, {len(barks)} игровых реакций, "
        f"всего {len(tasks)} файлов. Готово ранее: {skipped}, осталось: {len(todo)}."
    )
    print(f"Модель: {MODEL}; параллельно запросов: {MAX_WORKERS}; пауза между запросами: {REQUEST_START_GAP:.1f} с.")

    target_branch = os.environ.get("GITHUB_REF_NAME", "main")
    completed = []
    failures = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        for chunk_start in range(0, len(todo), CHUNK_SIZE):
            chunk = todo[chunk_start:chunk_start + CHUNK_SIZE]
            futures = {pool.submit(generate_one, api_key, task): task for task in chunk}
            results = []
            for future in concurrent.futures.as_completed(futures):
                task = futures[future]
                try:
                    results.append(future.result())
                except Exception as exc:
                    failures.append((task, str(exc)))
                    print(f"::error title=Не создана озвучка::{task['id']}: {exc}")

            if results:
                completed.extend(results)
                files = [record["task"]["output"] for record in results]
                label = f"batch {chunk_start // CHUNK_SIZE + 1:02d}"
                commit_and_push(files, label, target_branch)
                print(f"Сохранён пакет {label}: {len(results)} файлов.")

            if failures:
                print(
                    "::error::Есть ошибки генерации. Успешные файлы сохранены в main; "
                    "повторный запуск продолжит с отсутствующих файлов."
                )
                return 1

    missing = []
    manifest_entries = []
    for task in tasks:
        path = ROOT / task["output"]
        if not path.is_file() or path.stat().st_size == 0:
            missing.append(task["output"].as_posix())
            continue
        try:
            duration = probe_duration(path)
        except Exception:
            missing.append(task["output"].as_posix())
            continue
        if not 0.10 <= duration <= task["max_seconds"]:
            missing.append(task["output"].as_posix())
            continue
        manifest_entries.append({
            "kind": task["kind"],
            "id": task["id"],
            "speaker": task["speaker"],
            "file": task["output"].as_posix(),
            "voice": task["voice"],
            "duration_seconds": round(duration, 2),
        })

    if missing:
        print("::error title=Неполный пакет озвучки::" + ", ".join(missing[:20]))
        return 1

    manifest = {
        "schema_version": 1,
        "language": "ru-RU",
        "model": MODEL,
        "story_lines": len(story),
        "bark_clips": len(barks),
        "total_audio_files": len(manifest_entries),
        "voices": selected_voices,
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "files": manifest_entries,
    }
    manifest_file = ROOT / MANIFEST_PATH
    manifest_file.parent.mkdir(parents=True, exist_ok=True)
    manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    commit_and_push([MANIFEST_PATH], "coverage manifest", target_branch)

    print(
        f"[VOICEOVER COMPLETE] {len(story)} сюжетных строк и {len(barks)} игровых реакций; "
        f"{len(manifest_entries)} файлов проверены через ffprobe."
    )
    print(f"Манифест покрытия: {MANIFEST_PATH.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
