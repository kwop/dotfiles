#!/bin/sh
# Applications par défaut des fichiers texte et code : VS Code partout, au lieu de
# Warp, Xcode, IDLE ou Ghostty (qui exécutait les .sh). Sert au Cmd+clic sur les
# liens d'eza (--hyperlink) comme au double-clic dans le Finder. Gardés tels quels :
# .csv (Numbers), .html (Chrome), .log (Console). Relancé par chezmoi quand ce
# fichier change ; nécessite duti (Brewfile).
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v duti >/dev/null || { echo "default-apps : duti absent (brew install duti)" >&2; exit 1; }

# Uniquement des extensions dont macOS connaît le type (UTI). Pour .env, .conf, .kdl
# et .go, le type est « dynamique » et duti échoue (erreur -50) : à régler à la main
# (Finder, Lire les informations, Ouvrir avec, Tout modifier).
# Attention : .ts est aussi le type des vidéos MPEG-2 TS, ouvertes alors dans VS Code.
for ext in md txt toml json yaml yml xml ini sh zsh py js ts; do
  duti -s com.microsoft.VSCode ".$ext" all
done
