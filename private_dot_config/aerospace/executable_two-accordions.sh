#!/usr/bin/env bash
# Range les fenêtres du workspace 1 en deux colonnes côte à côte, chacune en
# accordéon vertical (une seule fenêtre visible par côté).
# Chaque application est envoyée dans la colonne définie ci-dessous.
# Déclenché par on-window-detected (nouvelle fenêtre) ou par alt-shift-a
# (avec --force : reconstruction inconditionnelle).
# Avec --resize-only (callbacks de focus / workspace / écran) : ne reconstruit
# rien, réapplique seulement la largeur de la colonne gauche quand le
# workspace a changé d'écran.
# Les fenêtres flottantes (dialogues, alertes, demandes d'autorisation…) ne
# déclenchent rien et restent hors des colonnes.
# Avec --maybe-popup (nouvelle fenêtre Chrome, détectée en flottante par la règle
# d'aerospace.toml pour garder sa taille d'origine) : si elle est étroite (popup de
# connexion, OAuth, extension…), elle reste flottante sans reconstruction ;
# sinon elle repasse en tuile et la reconstruction a lieu.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

WS=1
FORCE=0
RESIZE_ONLY=0
MAYBE_POPUP=0
case "${1:-}" in
  --force) FORCE=1 ;;
  --resize-only) RESIZE_ONLY=1 ;;
  --maybe-popup) MAYBE_POPUP=1 ;;
esac

# ---- Affectation des applications (bundle id) à une colonne ----------------
RIGHT_APPS="com.google.Chrome"
LEFT_APPS="org.whispersystems.signal-desktop net.whatsapp.WhatsApp com.apple.MobileSMS com.anthropic.claudefordesktop com.openai.chat com.apple.finder com.apple.systempreferences"
DEFAULT_SIDE="left"   # colonne des applications non listées
LEFT_WIDTH_PCT=25     # largeur de la colonne gauche en % de l'écran (la droite prend le reste)
LEFT_MIN_PX=600       # …sans descendre sous cette largeur : certaines apps de gauche ont une
                      # largeur minimale et débordaient sur Chrome (écran du MacBook)
POPUP_MAX_PCT=60      # fenêtre Chrome plus étroite que ce % de l'écran = popup
# -----------------------------------------------------------------------------

PIDFILE="${TMPDIR:-/tmp}/aerospace-two-accordions.pid"
LOCKDIR="${TMPDIR:-/tmp}/aerospace-two-accordions.lock"
# Nom de l'écran sur lequel la largeur a été appliquée pour la dernière fois
STATEFILE="${TMPDIR:-/tmp}/aerospace-two-accordions.monitor"

# Partition gauche/droite selon l'application (les flottantes restent à part)
partition() {
  left=() right=() left_anchor=""
  local id layout app side
  while IFS='|' read -r id layout app; do
    [ -n "$id" ] || continue
    [ "$layout" = floating ] && continue
    side=$DEFAULT_SIDE
    case " $LEFT_APPS "  in *" $app "*) side=left; left_anchor=${left_anchor:-$id} ;; esac
    case " $RIGHT_APPS " in *" $app "*) side=right ;; esac
    if [ "$side" = left ]; then left+=("$id"); else right+=("$id"); fi
  done < <(aerospace list-windows --workspace "$WS" --format '%{window-id}|%{window-layout}|%{app-bundle-id}')
}

# Largeur relative des colonnes, recalculée à partir de la largeur réelle de
# l'écran qui héberge le workspace. AeroSpace ne conserve pas les proportions
# quand le workspace change d'écran : il répartit la différence de largeur à
# parts égales entre les colonnes, ce qui écrase la colonne étroite sur un
# écran plus petit.
# D'où le mode --resize-only, qui rappelle cette fonction après un changement
# d'écran.
apply_width() {
  (( ${#left[@]} > 0 && ${#right[@]} > 0 )) || return 0
  local idx monitor screen_w
  IFS='|' read -r idx monitor < <(aerospace list-windows --workspace "$WS" \
    --format '%{monitor-appkit-nsscreen-screens-id}|%{monitor-name}' | head -n1)
  screen_w=$(osascript -l JavaScript -e \
    'ObjC.import("AppKit"); $.NSScreen.screens.js.map(s => s.frame.size.width).join("\n")' \
    2>/dev/null | sed -n "${idx}p" | cut -d. -f1)
  if [ -n "${screen_w:-}" ] && [ "$screen_w" -gt 0 ] 2>/dev/null; then
    # Redimensionner via une appli explicitement à gauche : une fenêtre d'une
    # appli non listée a pu s'ouvrir ailleurs depuis la dernière reconstruction.
    local left_w=$(( screen_w * LEFT_WIDTH_PCT / 100 ))
    (( left_w < LEFT_MIN_PX )) && left_w=$LEFT_MIN_PX
    aerospace resize --window-id "${left_anchor:-${left[0]}}" width "$left_w" \
      && echo "$monitor" > "$STATEFILE"
  fi
}

# Mode léger, appelé à chaque changement de focus : un seul appel à aerospace
# tant que le workspace reste visible sur le même écran.
if (( RESIZE_ONLY )); then
  [ -d "$LOCKDIR" ] && exit 0   # une reconstruction est en cours
  ws_info=$(aerospace list-workspaces --all --format '%{workspace}|%{workspace-is-visible}|%{monitor-name}' \
    | awk -F'|' -v ws="$WS" '$1 == ws { print $2 "|" $3 }')
  [ "${ws_info%%|*}" = true ] || exit 0   # invisible : ses colonnes ne sont pas encore redisposées
  [ "$(cat "$STATEFILE" 2>/dev/null)" = "${ws_info#*|}" ] && exit 0
  sleep 0.3   # laisser AeroSpace finir de redisposer le workspace sur le nouvel écran
  partition
  apply_width
  exit 0
fi

# Largeur d'une fenêtre en % de l'écran qui la contient (vide si inconnue).
# Lue auprès de macOS : AeroSpace ne donne pas la taille des fenêtres.
window_width_pct() {
  osascript -l JavaScript -e '
    ObjC.import("CoreGraphics"); ObjC.import("AppKit");
    function run(argv) {
      const list = ObjC.castRefToObject($.CGWindowListCopyWindowInfo(8, parseInt(argv[0])));
      if (list.count < 1) return "";
      const b = list.objectAtIndex(0).objectForKey("kCGWindowBounds");
      const x = b.objectForKey("X").js, w = b.objectForKey("Width").js, cx = x + w / 2;
      let sw = 0;
      for (const s of $.NSScreen.screens.js) {
        const f = s.frame;
        if (cx >= f.origin.x && cx < f.origin.x + f.size.width) { sw = f.size.width; break; }
      }
      if (!sw) sw = $.NSScreen.mainScreen.frame.size.width;
      return String(Math.round(w * 100 / sw));
    }' "$1" 2>/dev/null
}

# Nouvelle fenêtre Chrome, arrivée flottante (taille d'origine intacte) : une
# popup reste flottante et ne déclenche rien ; une vraie fenêtre (ou une taille
# illisible) repasse en tuile, puis la reconstruction continue normalement.
if (( MAYBE_POPUP )) && [ -n "${AEROSPACE_WINDOW_ID:-}" ]; then
  pct=$(window_width_pct "$AEROSPACE_WINDOW_ID")
  if [ -n "$pct" ] && [ "$pct" -lt "$POPUP_MAX_PCT" ] 2>/dev/null; then
    exit 0
  fi
  aerospace layout tiling --window-id "$AEROSPACE_WINDOW_ID"
fi

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
echo $$ > "$PIDFILE"
sleep 0.4
[ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ] || exit 0

# Verrou : ne pas reconstruire pendant qu'une autre instance reconstruit déjà.
for _ in $(seq 1 25); do
  if mkdir "$LOCKDIR" 2>/dev/null; then
    trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
    break
  fi
  sleep 0.2
done

focused=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)

partition

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

apply_width

# Restaurer le focus initial
[ -n "$focused" ] && aerospace focus --window-id "$focused" 2>/dev/null

exit 0
