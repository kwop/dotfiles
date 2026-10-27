#!/bin/bash
# Clignotement de la bordure au changement de focus (appelé par on-focus-changed
# dans aerospace.toml) : couleur, transparent, couleur, transparent, couleur.
# `borders <options>` met à jour l'instance qui tourne déjà, sans la redémarrer.
# Un clignotement en cours est interrompu par le suivant, qui se termine de toute
# façon sur la couleur normale.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ON='glow(0xfffacc15)'   # = active_color dans bordersrc
OFF=0x00000000
PIDFILE="${TMPDIR:-/tmp}/borders-flash.pid"
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
echo $$ > "$PIDFILE"
for c in "$OFF" "$ON" "$OFF" "$ON"; do
  borders active_color="$c"
  sleep 0.09
done
