# Alias eza, communs à belaz et agent
# Désactivés pour Claude Code car --icons cause des erreurs
# --hyperlink : noms cliquables (Cmd+clic dans Ghostty, aussi à travers Zellij)
if [[ -z "$CLAUDECODE" ]] && (( $+commands[eza] )); then
   alias ls='eza -a --git --icons --hyperlink --group-directories-first'
   unalias ll la lt 2>/dev/null
   ll() { eza -lag --git --git-repos --icons --hyperlink "$@"; }
   la() { eza -la --git --git-repos --icons --hyperlink "$@"; }
   lt() { eza --tree --level=2 --icons --hyperlink "$@"; }
   (( $+functions[compdef] )) && compdef _eza ll la lt
fi
