#!/usr/bin/env bash
# Range les fenêtres du workspace 1 en deux colonnes côte à côte, chacune en
# accordéon vertical (une seule fenêtre visible par côté).
# Chaque application est envoyée dans la colonne définie ci-dessous.
# Déclenché par on-window-detected (nouvelle fenêtre) ou par alt-shift-a
# (avec --force : reconstruction inconditionnelle).
# Les fenêtres flottantes (dialogues, alertes, demandes d'autorisation…) ne
# déclenchent rien et restent hors des colonnes.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WS=1
FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

# ---- Affectation des applications (bundle id) à une colonne ----------------
RIGHT_APPS="com.google.Chrome"
LEFT_APPS="org.whispersystems.signal-desktop net.whatsapp.WhatsApp com.apple.MobileSMS com.anthropic.claudefordesktop com.openai.chat com.apple.finder com.apple.systempreferences"
DEFAULT_SIDE="left"   # colonne des applications non listées
LEFT_WIDTH_PCT=40     # largeur de la colonne gauche en % de l'écran (la droite prend le reste)
# -----------------------------------------------------------------------------

# AeroSpace transmet la fenêtre détectée dans AEROSPACE_WINDOW_ID. Si elle est
# flottante (ou déjà refermée), il n'y a rien à ranger. Ce test passe avant
# l'anti-rafale pour ne pas annuler la reconstruction demandée juste avant par
# une vraie fenêtre.
if (( ! FORCE )) && [ -n "${AEROSPACE_WINDOW_ID:-}" ]; then
  layout=$(aerospace list-windows --all --format '%{window-id}|%{window-layout}' \
    | awk -F'|' -v id="$AEROSPACE_WINDOW_ID" '$1 == id { print $2 }')
  case "$layout" in ''|floating) exit 0 ;; esac
fi

# Anti-rafale : si plusieurs fenêtres sont détectées d'un coup (ex. démarrage
# d'AeroSpace), seule la dernière instance lancée reconstruit la disposition.
PIDFILE="${TMPDIR:-/tmp}/aerospace-two-accordions.pid"
echo $$ > "$PIDFILE"
sleep 0.4
[ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ] || exit 0

# Verrou : ne pas reconstruire pendant qu'une autre instance reconstruit déjà.
LOCKDIR="${TMPDIR:-/tmp}/aerospace-two-accordions.lock"
for _ in $(seq 1 25); do
  if mkdir "$LOCKDIR" 2>/dev/null; then
    trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
    break
  fi
  sleep 0.2
done

focused=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)

# Partition gauche/droite selon l'application (les flottantes restent à part)
left=() right=()
while IFS='|' read -r id layout app; do
  [ -n "$id" ] || continue
  [ "$layout" = floating ] && continue
  side=$DEFAULT_SIDE
  case " $LEFT_APPS "  in *" $app "*) side=left ;; esac
  case " $RIGHT_APPS " in *" $app "*) side=right ;; esac
  if [ "$side" = left ]; then left+=("$id"); else right+=("$id"); fi
done < <(aerospace list-windows --workspace "$WS" --format '%{window-id}|%{window-layout}|%{app-bundle-id}')

n=$(( ${#left[@]} + ${#right[@]} ))
(( n < 2 )) && exit 0

# Tout évacuer vers un workspace tampon : au retour, chaque fenêtre est
# insérée tout à droite de la racine, ce qui rend la construction déterministe
# sans jamais manipuler le focus.
for id in ${left[@]+"${left[@]}"} ${right[@]+"${right[@]}"}; do
  aerospace move-node-to-workspace --window-id "$id" tmp-accordions
done

build_column() {
  # $@ : fenêtres de la colonne, ramenées une à une depuis le tampon
  local first=$1 count=$#
  aerospace move-node-to-workspace --window-id "$first" "$WS"
  aerospace layout h_tiles --window-id "$first"      # garantit une racine horizontale
  (( count < 2 )) && return 0
  shift
  aerospace move-node-to-workspace --window-id "$1" "$WS"
  aerospace join-with right --window-id "$first"   # crée le conteneur de la colonne
  shift
  for id in "$@"; do
    aerospace move-node-to-workspace --window-id "$id" "$WS"
    aerospace move left --window-id "$id"          # entre dans le conteneur voisin
  done
  aerospace layout v_accordion --window-id "$first"
}

(( ${#left[@]}  > 0 )) && build_column "${left[@]}"
(( ${#right[@]} > 0 )) && build_column "${right[@]}"

# Largeur relative des colonnes : on recalcule à partir de la largeur réelle
# de l'écran qui héberge le workspace, pour rester correct en changeant d'écran.
if (( ${#left[@]} > 0 && ${#right[@]} > 0 )); then
  idx=$(aerospace list-windows --workspace "$WS" --format '%{monitor-appkit-nsscreen-screens-id}' | head -n1)
  screen_w=$(osascript -l JavaScript -e \
    'ObjC.import("AppKit"); $.NSScreen.screens.js.map(s => s.frame.size.width).join("\n")' \
    2>/dev/null | sed -n "${idx}p" | cut -d. -f1)
  if [ -n "${screen_w:-}" ] && [ "$screen_w" -gt 0 ] 2>/dev/null; then
    aerospace resize --window-id "${left[0]}" width $(( screen_w * LEFT_WIDTH_PCT / 100 ))
  fi
fi

# Restaurer le focus initial
[ -n "$focused" ] && aerospace focus --window-id "$focused" 2>/dev/null

exit 0
