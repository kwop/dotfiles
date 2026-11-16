#!/usr/bin/env bash
# Regroupe toutes les fenêtres d'UNE application, dans un workspace, en un seul
# accordéon : elles n'occupent plus qu'une seule tuile, à côté des autres
# fenêtres du workspace (ou tout l'écran s'il n'y en a pas d'autres).
# Usage : group-app.sh [--force] <workspace> <bundle-id>
# Raison d'être : AeroSpace compte chaque ONGLET du Finder comme une fenêtre ;
# un Finder à 4 onglets, seul dans le workspace 6, n'avait qu'un quart de la
# largeur.
# Les fenêtres flottantes (dialogues…) ne déclenchent rien et restent flottantes.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

FORCE=0
[ "${1:-}" = "--force" ] && { FORCE=1; shift; }
WS="${1:?workspace}"
APP="${2:?bundle id}"
TMP=tmp-accordions   # même tampon que two-accordions.sh (ignoré par son rattrapage)

# Fenêtre détectée (AEROSPACE_WINDOW_ID) flottante ou déjà refermée : rien à faire.
if (( ! FORCE )) && [ -n "${AEROSPACE_WINDOW_ID:-}" ]; then
  layout=$(aerospace list-windows --all --format '%{window-id}|%{window-layout}' \
    | awk -F'|' -v id="$AEROSPACE_WINDOW_ID" '$1 == id { print $2 }')
  case "$layout" in ''|floating) exit 0 ;; esac
fi

# Anti-rafale : si plusieurs fenêtres sont détectées d'un coup, seule la
# dernière instance reconstruit la disposition.
PIDFILE="${TMPDIR:-/tmp}/aerospace-group-app-${WS}-${APP}.pid"
echo $$ > "$PIDFILE"
sleep 0.3
[ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ] || exit 0

ids=() others=0 grouped=1
while IFS='|' read -r id layout app parent; do
  [ -n "$id" ] || continue
  [ "$layout" = floating ] && continue
  if [ "$app" = "$APP" ]; then
    ids+=("$id")
    case "$parent" in *accordion) ;; *) grouped=0 ;; esac
  else
    others=$(( others + 1 ))
  fi
done < <(aerospace list-windows --workspace "$WS" \
  --format '%{window-id}|%{window-layout}|%{app-bundle-id}|%{window-parent-container-layout}')

(( ${#ids[@]} < 2 )) && exit 0
# Déjà toutes en accordéon : rien à reconstruire (évite le clignotement).
(( ! FORCE && grouped )) && exit 0

focused=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null || true)
first=${ids[0]}

if (( others == 0 )); then
  # Seule application du workspace : un accordéon unique suffit.
  aerospace flatten-workspace-tree --workspace "$WS"
  aerospace layout v_accordion --window-id "$first"
else
  # Évacuer ses fenêtres vers le tampon : au retour, chacune est insérée tout à
  # droite de la racine, ce qui rend la construction déterministe.
  for id in "${ids[@]}"; do
    aerospace move-node-to-workspace --window-id "$id" "$TMP"
  done
  aerospace move-node-to-workspace --window-id "$first" "$WS"
  aerospace layout h_tiles --window-id "$first"      # racine horizontale
  aerospace move-node-to-workspace --window-id "${ids[1]}" "$WS"
  aerospace join-with right --window-id "$first"     # crée le conteneur
  for id in "${ids[@]:2}"; do
    aerospace move-node-to-workspace --window-id "$id" "$WS"
    aerospace move left --window-id "$id"            # entre dans le conteneur voisin
  done
  aerospace layout v_accordion --window-id "$first"
fi

[ -n "$focused" ] && aerospace focus --window-id "$focused" 2>/dev/null
exit 0
