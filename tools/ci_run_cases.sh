#!/bin/bash
# Прогон набора самотестов Godot. Каждый тест идёт отдельным процессом со своим профилем,
# поэтому общий сейв не мешает. Аргумент: список "метка=аргументы" через пробел,
# например: sim=--sim layout_ru=--layout,--lang=ru
# Запятая внутри аргументов разделяет параметры одного запуска.
set -uo pipefail
LIMIT="${CASE_TIMEOUT:-150}"
failed=0
: > /tmp/pustite-failures
for spec in "$@"; do
  label="${spec%%=*}"
  args="${spec#*=}"
  IFS=',' read -r -a argv <<< "$args"
  profile="/tmp/pustite-$label"
  mkdir -p "$profile/data" "$profile/config" "$profile/cache"
  log="/tmp/pustite-$label.log"
  started=$SECONDS
  status=0
  XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" XDG_CACHE_HOME="$profile/cache" \
    timeout "$LIMIT" godot --headless --path game --log-file "/tmp/pustite-$label-engine.log" -- "${argv[@]}" > "$log" 2>&1 || status=$?
  took=$((SECONDS - started))
  if [ "$status" -ne 0 ] || grep -q "SCRIPT ERROR" "$log"; then
    reason="код $status"
    [ "$status" -eq 124 ] && reason="превышен лимит ${LIMIT}с, возможно зависание"
    grep -q "SCRIPT ERROR" "$log" && reason="$reason, SCRIPT ERROR"
    echo "FAIL $label (${took}с, $reason)"
    echo "$label" >> /tmp/pustite-failures
    failed=1
  else
    echo "PASS $label (${took}с)"
  fi
done
if [ "$failed" -ne 0 ]; then
  while read -r label; do
    echo "::group::Лог $label"
    tail -n 80 "/tmp/pustite-$label.log"
    echo "::endgroup::"
  done < <(sort -u /tmp/pustite-failures)
  while read -r label; do
    short=$(grep -E "✗|ПРОВАЛ|НАРУШЕНИЙ|SCRIPT ERROR|ТАЙМАУТ" "/tmp/pustite-$label.log" | head -6 | cut -c1-300 | paste -sd'|' -)
    echo "::error title=Провал $label::${short:-нет строк с причиной, смотри хвост лога}"
  done < <(sort -u /tmp/pustite-failures)
  echo "::error title=Самотесты не пройдены::Упавшие: $(sort -u /tmp/pustite-failures | tr '\n' ' ')"
  exit 1
fi
echo "Набор пройден."
