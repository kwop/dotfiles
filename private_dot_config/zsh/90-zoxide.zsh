# zoxide, commun à belaz et agent. Module chargé en dernier (recommandation zoxide)
if command -v zoxide &> /dev/null; then
  if [[ -z "$CLAUDECODE" ]]; then
    # Shell normal : zoxide remplace cd
    eval "$(zoxide init --cmd cd zsh)"
  else
    # Shell Claude : zoxide utilise 'z', cd reste natif (évite bug snapshot)
    eval "$(zoxide init zsh)"
  fi
fi
