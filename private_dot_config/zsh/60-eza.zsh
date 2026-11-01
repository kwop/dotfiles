# Alias eza, communs à belaz et agent
# Désactivés pour Claude Code car --icons cause des erreurs
# --hyperlink : noms cliquables (Cmd+clic dans Ghostty, aussi à travers Zellij)
# --icons et --hyperlink en tête, suivis d'une autre option : depuis eza 0.23.5, ils
# prennent le mot suivant comme valeur ([WHEN]), et « ll code » échouait
if [[ -z "$CLAUDECODE" ]] && (( $+commands[eza] )); then
   alias ls='eza --icons --hyperlink -a --git --group-directories-first'
   unalias ll la lt 2>/dev/null
   ll() { eza --icons --hyperlink -lag --git --git-repos "$@"; }
   la() { eza --icons --hyperlink -la --git --git-repos "$@"; }
   lt() { eza --icons --hyperlink --tree --level=2 "$@"; }
   (( $+functions[compdef] )) && compdef _eza ll la lt
fi
