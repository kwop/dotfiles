#!/usr/bin/env bash
# Range toutes les fenêtres d'un workspace dans UN seul accordéon vertical
# (une fenêtre visible à la fois, en plein écran, pas de côte à côte).
# Usage : single-accordion.sh [--force] [workspace]   (défaut : 2)
# Les fenêtres flottantes (dialogues…) ne déclenchent rien et restent flottantes.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

FORCE=0
[ "${1:-}" = "--force" ] && { FORCE=1; shift; }
WS="${1:-2}"

# Fenêtre détectée (AEROSPACE_WINDOW_ID) flottante ou déjà refermée : rien à
# faire. Avant l'anti-rafale pour ne pas annuler une vraie reconstruction.
if (( ! FORCE )) && [ -n "${AEROSPACE_WINDOW_ID:-}" ]; then
  layout=$(aerospace list-windows --all --format '%{window-id}|%{window-layout}' \
    | awk -F'|' -v id="$AEROSPACE_WINDOW_ID" '$1 == id { print $2 }')
  case "$layout" in ''|floating) exit 0 ;; esac
fi

# Anti-rafale : si plusieurs fenêtres sont détectées d'un coup, seule la
# dernière instance reconstruit la disposition.
PIDFILE="${TMPDIR:-/tmp}/aerospace-single-accordion-${WS}.pid"
echo $$ > "$PIDFILE"
sleep 0.3
[ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ] || exit 0

# Première fenêtre en tuile (une flottante ferait échouer 'layout')
id=$(aerospace list-windows --workspace "$WS" --format '%{window-id}|%{window-layout}' \
  | awk -F'|' '$2 != "floating" { print $1; exit }')
[ -n "$id" ] || exit 0

aerospace flatten-workspace-tree --workspace "$WS"
aerospace layout v_accordion --window-id "$id"

exit 0
