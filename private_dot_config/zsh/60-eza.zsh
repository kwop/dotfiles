# Alias eza, communs à belaz et agent
# Désactivés pour Claude Code car --icons cause des erreurs
if [[ -z "$CLAUDECODE" ]] && (( $+commands[eza] )); then
   alias ls='eza -a --git --icons --group-directories-first'
   unalias ll la lt 2>/dev/null
   ll() { eza -lag --git --git-repos --icons "$@"; }
   la() { eza -la --git --git-repos --icons "$@"; }
   lt() { eza --tree --level=2 --icons "$@"; }
   (( $+functions[compdef] )) && compdef _eza ll la lt
fi
