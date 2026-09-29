#!/usr/bin/env bash
# Range toutes les fenêtres d'un workspace dans UN seul accordéon vertical
# (une fenêtre visible à la fois, en plein écran, pas de côte à côte).
# Usage : single-accordion.sh [workspace]   (défaut : 2)
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WS="${1:-2}"

# Anti-rafale : si plusieurs fenêtres sont détectées d'un coup, seule la
# dernière instance reconstruit la disposition.
PIDFILE="${TMPDIR:-/tmp}/aerospace-single-accordion-${WS}.pid"
echo $$ > "$PIDFILE"
sleep 0.3
[ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ] || exit 0

id=$(aerospace list-windows --workspace "$WS" --format '%{window-id}' | head -n1)
[ -n "$id" ] || exit 0

aerospace flatten-workspace-tree --workspace "$WS"
aerospace layout v_accordion --window-id "$id"

exit 0
