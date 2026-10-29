#!/usr/bin/env python3
"""Refresh game sound assets from checksum-pinned public CC sources.

Runs on GitHub Actions runner. It does not run on the developer's PC.
"""
from __future__ import annotations

import hashlib
import shutil
import subprocess
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

META_REV = "251c0be57d5d1b3242b91f53e0cde62ab1cb42d9"
META_BASE = (
    "https://raw.githubusercontent.com/facebookincubator/Meta-open-sound/"
    + META_REV
    + "/corpora/oculus-audio-pack/ogg/"
)

# Source filename, SHA-256, output names in game/assets/sfx.
META = [
    ("AMBForst_Forest_LOOP_01.ogg", "9da161682bcd32866f99c1dfc190ea3240d114f44beb88ff7521fe5f25d059a2", ["amb_day.ogg"]),
    ("AMBForst_Night_LOOP_01.ogg", "ff62723c83eececdd4fc3c4707a7e35d4216d1fda84a07718464fa8f5d56d461", ["amb_night.ogg"]),
    ("WINDVege_LightWindTreesBirds_LOOP_01.ogg", "94fc6b8764cf54f5b9d1dc95f7bce03c356fa0bf99f12c1a76b610d116812744", ["amb_dusk.ogg"]),
    ("WATRFlow_CreekInWoods_LOOP_01.ogg", "a48062908ad32ef336e78163cbebe83ab021e48b4c055afe74a3525ae195908e", ["amb_river.ogg"]),
    ("WATRFlow_River_LOOP_01.ogg", "d820a72939f6249e04a1748b376143fc3bd7ce820fbbe93c6109072d1fbc0967", ["mill_wheel.ogg"]),
    ("AMBFarm_FarmGeneric_LOOP_01.ogg", "395d16f6fbbac45acf16e298dbe4cc3a1fb6a38923eb83eddf4911d78cde99b3", ["life_murmur.ogg"]),
    ("ANMLDog_DogBark_OS_01.ogg", "789f9fd6e3978669a89c36ac5504f1b99aba4a97f26548dead35a7cb86a5f67e", ["life_dog.ogg"]),
    ("BIRDFowl_Chicken_OS_01.ogg", "a34441f0792e6eef21e8a8660fb39f0d96c5d780d8863509e67bbe0745be07c5", ["life_hens.ogg"]),
    ("DOORWood_FrontDoorOpen_OS_01.ogg", "03f9b072f79a7ceb8fa8b3b101f7a3c2a7919f5b1d6b61c7be7f4c089ee9a2ec", ["door_open.ogg"]),
    ("DOORWood_FrontDoorClose_OS_01.ogg", "f7c566d2e6df619de2fb2bdc66799d5ca632c1bc323a01dc8fdfad18c151314c", ["door_shut.ogg", "exile.ogg"]),
    ("DOORHdwr_FrontDoorLock_OS_01.ogg", "71df8cf1d0f0a2531cd4835a1c61ebc03b11d1eab736264d381b8216664f8eb9", ["latch.ogg"]),
    ("DOORKnck_OfficeDoorKnock_OS_01.ogg", "f68404b7a37796f345a5906cf9c4f478598bbd1bce83520a1e5e2fd8fb32440c", ["knock.ogg"]),
    ("FEETHmn_ShoeWoodWalk_OS_01.ogg", "f8fbe8f5b82f419cc3bae22818a586fe3db611596590788501b0de6bd7e31685", ["roof_steps.ogg"]),
    ("FEETHmn_ShoeWoodWalk_OS_02.ogg", "af53d16669f53a95bd698829b76dd0bab3e80fce9c6c517d89b5cc8a543910fa", ["floorboard.ogg"]),
    ("WOODFric_CreaksCreepy_OS_01.ogg", "e02ca654ca67ece1429927317ec90aa355d8d0fdcfd089500240c33bcb36f3bf", ["creak.ogg"]),
    ("WOODImpt_LargeWoodDrop_OS_01.ogg", "2047aecd791504d99607b6dc055273091103b559f96b6327ba9128c618121feb", ["death.ogg", "reveal_3.ogg"]),
    ("METLFric_ScratchCreepy_OS_01.ogg", "66084ac1320ac2d9ca2aae04ae3634302ce8cc8d3c2a37e3fb85d06d0c17a1f4", ["scratch.ogg"]),
    ("VOXWhsp_WhispersCreepy_OS_01.ogg", "347f1eb966f9767a2bc4f7d23bb07b6dd09403ea0b00c072527bb6a1a068f112", ["whisper.ogg"]),
    ("VOXWhsp_WhispersCreepyReverb_OS_01.ogg", "c501c17465a858ebf9ecfa5f9381403e8fbc068f7a8c623e03a0d31869a3ba3e", ["call_far.ogg"]),
    ("CREAMnstr_CreatureCreepy_OS_01.ogg", "b73e8cda8eaea10ec32975491822a156388cd74de3ab10816009333132f74463", ["growl.ogg"]),
    ("CREAMnstr_CreatureCreepyReverb_OS_01.ogg", "9b10b79d8125f8943f30f809a7dd4ec0165b520dfc73aa917f5617fa0e46ef06", ["upyr_cry.ogg"]),
    ("CREAMnstr_CreatureCreepyReverb_OS_02.ogg", "12d38e6eefe4a834ae0f0128981b22377393bec930bcb806da2807293cd8df8b", ["breath_3.ogg"]),
    ("CREAMnstr_CreatureCreepyReverb_OS_03.ogg", "bd6704d3e659b8ca3108d56bfebfcadb31ec8f175ca666297807ca49ce142b6f", ["scare.ogg"]),
    ("VOXFem_GroanCreepy_OS_01.ogg", "18cffefe40e290a8e04d3d1ae2ec735ec74fc95e020d110738cb311da8922c03", ["weep.ogg"]),
    ("VOXMale_GroanCreepy_OS_01.ogg", "01c8d3c0cda31fdd65fc823d2b3903d6d988d18d7c5e810cf9e958163af5e32e", ["cry_far.ogg"]),
    ("VOXFem_Female01Death_OS_01.ogg", "c8b3aad56a3d8c63f5a86174f17494cc754781ae539ae590dea12fcf278078e7", ["human_cry_f.ogg"]),
    ("VOXMale_Male01Death_OS_01.ogg", "f38ea68e20714e2b0be24cec63cdb76b5d5805276626cbff705a0751fb2e090d", ["human_cry_m.ogg"]),
    ("VOXFem_Female01Hurt_OS_01.ogg", "23c5403c874a94622b04e0dae450b092fa68480f2237cb5d40d3e26693ad4b40", ["gasp.ogg"]),
    ("HMNBrth_MaleBreathing_OS_01.ogg", "3f4a257c984fb921df5683e4973433f9c2d6221b8a9326cd5ba6741a332e3aa4", ["breath.ogg"]),
    ("HMNBrth_FemaleBreathing_OS_01.ogg", "6fe24ce3670fcb14f1730578b0af66389e760f93e3c3941bfc2ded94de0e4b2f", ["breath_2.ogg"]),
    ("UIClick_WoodBack_OS_01.ogg", "6037c03072ceb55b24c39f83ecaaa67380ba9973cde1f7b60cb07160f98d8ea2", ["tap.ogg"]),
    ("UIClick_WoodConfirm_OS_01.ogg", "ac28a77f418e353b50ed9071e54f2c9028a3daf145a3e0b82a0bdc2092ba2730", ["blip.ogg", "win.ogg", "job_done.ogg", "reveal_2.ogg"]),
    ("UIAlert_WoodError_OS_01.ogg", "c2edc4294fc09b50bd67e4c21ee12a58242720e9ac7aa605a9a336ef858002e3", ["lose.ogg", "job_fail.ogg"]),
    ("CLOCKTick_ClockCreepy_OS_01.ogg", "41a00c5dfc4d405cbf3d9fff819957c11de1cd755a7d1ba4544761533532f783", ["tick.ogg"]),
    ("GLASBrk_GlassBottleBreak_OS_01.ogg", "f1ce5b8b0f4bb6d5a9de27c9119daa68847f07977ae9db6059fd05d7bcbb8af3", ["cup_break.ogg"]),
    ("METLImpt_HammerAnvil_OS_01.ogg", "27b6333e7a5bd02ee64878829b4fdd31e8e09e1d8419d18f56c417bae9d1231d", ["hammer.ogg", "reveal.ogg"]),
    ("AMBForst_ForestBirds_OS_01.ogg", "d6d3a97c0d23f86d1db865a5d24adc00851f67dab4a6ea776fb660df44ac88c8", ["dawn.ogg"]),
]

# SFX Jar / BigSoundBank files are published under CC0 1.0.
SFXJAR = [
    ("https://sfxjar.com/audio/0135.mp3", "63a6ac52590e46f5072ae1f296fb1fe0599466eaa9493877d3d342ad699f47d9", ["bell.ogg"]),
    ("https://sfxjar.com/audio/3009.mp3", "fe11ba54d6bc34f1d5dc187f827cff044172125a932e432818d3f7eec9e88c54", ["train.ogg"]),
    ("https://sfxjar.com/audio/3015.mp3", "89e1351998fea0878d1c41ec301d7652c5eedb150985c05012e534939567eb86", ["whistle.ogg"]),
    ("https://sfxjar.com/audio/3016.mp3", "ab8a82083a3d7dacad93cd5b5b0060795ec6d3dae2267292ec71065cbbc1a103", ["rails.ogg"]),
    ("https://sfxjar.com/audio/1065.mp3", "0ef68dc9d06e66b574d7b3c3496d7499644f4994082e0296cfeac55bbdf694e1", ["typewriter.ogg"]),
    ("https://sfxjar.com/audio/2718.mp3", "5576914d5ab184199356e0ce2a9a9afeace485d274dbd84f753587e0efd8c90e", ["thunder.ogg"]),
    ("https://sfxjar.com/audio/3114.mp3", "e5516eb3799c4f72154dd204d6ef4484efea6ebb6ab03225fd931b61056f2ca4", ["thunder_2.ogg", "thunder_far.ogg"]),
    ("https://sfxjar.com/audio/0146.mp3", "a66d7ad4576cdf50e37cf074bc4bf40e5d276f09e84af829caa64b99e15be880", ["amb_blizzard.ogg"]),
    ("https://sfxjar.com/audio/0625.mp3", "85ceec8b9113af997f27c446d823d708ff04d91231dfc06a002272bfaf19af1a", ["amb_wind.ogg"]),
    ("https://sfxjar.com/audio/0770.mp3", "cd387ace20710152f2169333075ca00936574234b30c82a99e3cd18b624610bc", ["heartbeat.ogg"]),
]

OBSOLETE = [
    "thunder_3.ogg",
    "thunder_4.ogg",
    "upyr_cry.wav",
]

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Pustite-sound-assets/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()

def checked_source(label: str, url: str, expected: str) -> bytes:
    data = fetch(url)
    actual = sha256(data)
    if actual != expected:
        raise RuntimeError(f"{label}: SHA-256 mismatch: expected {expected}, got {actual}")
    if len(data) < 4096:
        raise RuntimeError(f"{label}: source unexpectedly small ({len(data)} bytes)")
    return data

def to_ogg(data: bytes, ffmpeg: str) -> bytes:
    result = subprocess.run(
        [
            ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin",
            "-f", "mp3", "-i", "pipe:0", "-vn", "-c:a", "libvorbis",
            "-q:a", "5", "-f", "ogg", "pipe:1",
        ],
        input=data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=90,
    )
    if result.returncode or not result.stdout.startswith(b"OggS"):
        raise RuntimeError("MP3 to OGG conversion failed: " + result.stderr.decode("utf-8", "replace"))
    return result.stdout

def main() -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg is required on the GitHub runner")

    root = Path(__file__).resolve().parents[1] / "assets" / "sfx"
    root.mkdir(parents=True, exist_ok=True)
    removed = 0
    for name in OBSOLETE:
        for path in (root / name, root / (name + ".import")):
            if path.exists():
                path.unlink()
                removed += 1

    jobs: list[tuple[str, str, str, list[str]]] = []
    for source, expected, targets in META:
        jobs.append((source, META_BASE + source, expected, targets))
    for url, expected, targets in SFXJAR:
        jobs.append((url, url, expected, targets))

    print(f"Проверяю и загружаю {len(jobs)} записанных источников.")
    written: list[Path] = []
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = {
            pool.submit(checked_source, label, url, expected): (label, targets)
            for label, url, expected, targets in jobs
        }
        for future in as_completed(futures):
            label, targets = futures[future]
            data = future.result()
            converted = data if label.endswith(".ogg") else to_ogg(data, ffmpeg)
            if label.endswith(".ogg") and not data.startswith(b"OggS"):
                raise RuntimeError(f"{label}: source is not OGG")
            for name in targets:
                path = root / name
                path.write_bytes(converted)
                written.append(path)
            print(f"OK {label}: {len(data)} bytes -> {', '.join(targets)}")

    # Decode every output once before Godot imports it.
    for path in sorted(set(written)):
        result = subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin", "-i", str(path), "-f", "null", "-"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            check=False,
            timeout=90,
        )
        if result.returncode:
            raise RuntimeError(f"{path.name}: output decode failed: {result.stderr.decode('utf-8', 'replace')}")
        if path.stat().st_size < 4096:
            raise RuntimeError(f"{path.name}: output unexpectedly small")

    print(f"Готово: {len(set(written))} OGG-файлов декодируются; удалено старых файлов/импортов: {removed}.")

if __name__ == "__main__":
    main()
