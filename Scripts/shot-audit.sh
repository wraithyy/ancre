#!/usr/bin/env bash
# OCR gate for release media: fails if any screenshot/GIF/video frame contains
# a string from the deny list. Deny list lives OUTSIDE the repo so client and
# employer names never get committed.
#
#   Scripts/shot-audit.sh                 # all media under website/src/assets
#   Scripts/shot-audit.sh shot.png ...    # specific files
#
# Deny list: ~/.config/ancre-shots/deny.txt, one extended regex per line.
set -eo pipefail

deny="${ANCRE_SHOT_DENY:-$HOME/.config/ancre-shots/deny.txt}"
if [ ! -f "$deny" ]; then
  mkdir -p "$(dirname "$deny")"
  cat > "$deny" <<'SEED'
# One extended regex per line. Case-insensitive. Add employer, client and
# project names here. This file is intentionally outside the git repo.
@thetrask\.com
thetrask
trask
jkvapil
gitlab\.
jira
confluence
SEED
  echo "created deny list template: $deny -- add your client/project names, then rerun" >&2
  exit 2
fi

targets=("$@")
if [ $# -eq 0 ]; then
  targets=()
  while IFS= read -r f; do targets+=("$f"); done < <(
    find website/src/assets -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.gif' -o -name '*.mp4' -o -name '*.mov' \) 2>/dev/null
  )
fi
[ ${#targets[@]} -eq 0 ] && { echo "no media found"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

ocr() { # $1 = image path, $2 = label shown on a hit
  local hits
  hits=$(tesseract "$1" - --psm 11 2>/dev/null | grep -inE -f "$deny" || true)
  if [ -n "$hits" ]; then
    echo "LEAK $2"
    printf '%s\n' "$hits" | sed 's/^/    /'
    fail=1
  fi
}

for f in "${targets[@]}"; do
  case "$f" in
    *.png|*.jpg|*.jpeg) ocr "$f" "$f" ;;
    *.gif|*.mp4|*.mov)
      rm -rf "$tmp/frames"; mkdir -p "$tmp/frames"
      ffmpeg -loglevel error -i "$f" -vf fps=2 "$tmp/frames/%04d.png"
      for fr in "$tmp/frames"/*.png; do
        [ -e "$fr" ] || continue
        ocr "$fr" "$f frame $(basename "$fr" .png)"
      done ;;
  esac
done

[ $fail -eq 0 ] && echo "clean: ${#targets[@]} file(s)"
exit $fail
