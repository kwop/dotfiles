# atuin, commun à belaz et agent : historique du shell en base locale (Ctrl R). Chargé après
# 10-belaz.zsh et 10-agent.zsh, il reprend Ctrl R à fzf. Sans synchronisation : voir
# ~/.config/atuin/config.toml. Binaire : installeur officiel (~/.atuin/bin) ou brew sur le Mac
# principal, mise (cargo:atuin, pas de binaire macOS Intel) sur le Mac Intel.
# Désactivé pour Claude Code : ses commandes n'ont pas besoin de l'historique interactif.
[[ -r $HOME/.atuin/bin/env ]] && source "$HOME/.atuin/bin/env"
if [[ -z "$CLAUDECODE" ]] && (( $+commands[atuin] )); then
  eval "$(atuin init zsh)"
fi
