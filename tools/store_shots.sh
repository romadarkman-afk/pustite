#!/bin/bash
# Скриншоты для страницы в магазине (TASK-098).
# Запуск из любой папки: tools/store_shots.sh ПАПКА ЯЗЫК метка:вид:глава ...
# Виды: day, door, menu, camp. Размер по умолчанию 1080x1920 (RES=WxH меняет).
# Нужны godot 4.6 (переменная GODOT, по умолчанию godot) и xvfb-run.
# Пример (набор для магазина):
#   tools/store_shots.sh /tmp/store ru s1_summer:day:a1c3 s2_autumn:day:a2c1 s3_winter:day:a3c1 \
#     s4_spring:day:a4c1 s5_door_summer:door:a1c3 s6_door_winter:door:a3c1 s7_menu:menu s8_camp:camp
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT=$(realpath -m "$1"); LANG_CODE=$2; shift 2
mkdir -p "$OUT"
cd "$ROOT/game"
N="_store_shot_$$"   # свои имена на каждый запуск: можно гнать несколько языков параллельно
cp "$ROOT/tools/store_shot.gd" "$N.gd"
printf '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://%s.gd" id="1"]\n\n[node name="S" type="Node"]\nscript = ExtResource("1")\n' "$N" > "$N.tscn"
trap 'rm -f "$N.gd" "$N.gd.uid" "$N.tscn"' EXIT
export XDG_DATA_HOME=${XDG_DATA_HOME:-/tmp/store_shots/d$$} XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/tmp/store_shots/c$$} XDG_CACHE_HOME=${XDG_CACHE_HOME:-/tmp/store_shots/k$$}
# программная отрисовка: около 1,5 минут на кадр, на набор из шести кадров нужно до 12 минут
timeout "${SHOT_TIMEOUT:-1800}" xvfb-run -a "${GODOT:-godot}" --path . --rendering-driver opengl3 --resolution "${RES:-1080x1920}" "res://$N.tscn" -- "$OUT" "$LANG_CODE" "$@" 2>&1 | grep -E "SHOT|DONE|SCRIPT ERROR|ERROR|Parse|Failed" | head -30 || true
