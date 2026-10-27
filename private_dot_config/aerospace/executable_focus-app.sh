#!/bin/bash
# Affiche une application (Hyper + lettre, voir aerospace.toml).
# Usage : focus-app.sh <bundle-id> <nom de l'app pour open -a>
# - L'app n'a pas le focus : open -a la lance ou l'active, macOS ramène sa
#   dernière fenêtre utilisée et AeroSpace suit sur le bon workspace.
# - L'app a déjà le focus : passe à sa fenêtre suivante, en boucle.
set -u
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
bundle=$1 app=$2

# App réellement au premier plan selon macOS. AeroSpace ne voit pas certaines
# fenêtres, comme le quick terminal de Ghostty, et répondrait l'app d'en dessous.
# Sortie du type : bundleID="com.google.Chrome" (selon les versions de macOS,
# "CFBundleIdentifier"="…").
focused_app=$(lsappinfo info -only bundleid "$(lsappinfo front)" \
  | sed -nE 's/.*(bundleID|"CFBundleIdentifier")="([^"]+)".*/\2/p' | head -n1)
if [ "$focused_app" != "$bundle" ]; then
  open -a "$app"
  exit 0
fi

focused=$(aerospace list-windows --focused --format '%{window-id}')
ids=($(aerospace list-windows --monitor all --app-bundle-id "$bundle" --format '%{window-id}'))
(( ${#ids[@]} > 1 )) || exit 0
for i in "${!ids[@]}"; do
  if [ "${ids[$i]}" = "$focused" ]; then
    aerospace focus --window-id "${ids[$(( (i + 1) % ${#ids[@]} ))]}"
    exit 0
  fi
done
