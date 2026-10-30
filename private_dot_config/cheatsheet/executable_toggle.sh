#!/bin/bash
# Affiche ou masque l'aide-mémoire des raccourcis (Hyper + ?, voir aerospace.toml),
# dans une fenêtre Quick Look.
F="$HOME/.config/cheatsheet/raccourcis.html"
if pgrep -f "qlmanage -p $F" >/dev/null; then
  pkill -f "qlmanage -p $F"
  exit 0
fi
qlmanage -p "$F" >/dev/null 2>&1 &
pid=$!
# Lancée en arrière-plan, la fenêtre s'ouvre derrière l'app active, et AeroSpace
# ne voit pas les fenêtres Quick Look : on passe le processus au premier plan via
# System Events (macOS demande une fois l'autorisation pour AeroSpace).
for _ in 1 2 3; do
  sleep 0.25
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $pid) to true" \
    >/dev/null 2>&1
done
