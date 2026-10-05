# Config propre à belaz (outils de dev, chemins, complétions). Jamais déployée sur les
# autres comptes : voir .chezmoiignore. Les parties communes sont dans les autres modules.

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# DÉSACTIVÉ : casse l'affichage de Zellij (testé en 26.08.04). Avant ça : conflit
# carapace/zoxide/fzf causant 100% CPU, voir
# https://github.com/marlonrichert/zsh-autocomplete/issues/709
# source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh


fpath=(~/.zsh/completions $fpath)

export PATH="$PATH:$HOME/Applications/Android\ Studio.app/Contents/jbr/Contents/Home/bin"
export JAVA_HOME="$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$PATH":"$HOME/fvm/default/bin:$HOME/.pub-cache/bin:$HOME/go/bin:$HOME/Library/Android/sdk/platform-tools"

export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

LC_ALL=en_US.UTF-8

# fpath and completion initialization (must be before bashcompinit)
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
fpath=(~/.zsh/completion $fpath)
fpath=($HOME/.docker/completions $fpath)
# compinit explicite : avant, il n'était lancé que par le bash_completion de nvm.
autoload -Uz compinit && compinit


# Aliases
alias kctx="kubectx"
alias kns="kubens"
alias adb='$HOME/Library/Android/sdk/platform-tools/adb'
alias m='make'
alias curl='noglob curl'
alias k=kubectl


# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Kubectl completion
[[ /usr/local/bin/kubectl ]] && source <(kubectl completion zsh)
complete -F __start_kubectl k

# Terraform completion
complete -o nospace -C /opt/homebrew/bin/terraform terraform

# pipx
export PATH="$PATH:$HOME/.local/bin:$HOME/.docker/bin"

# tabtab source for packages
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true

# Dart CLI completion
[[ -f $HOME/.dart-cli-completion/zsh-config.zsh ]] && . $HOME/.dart-cli-completion/zsh-config.zsh || true

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

# Shorebird
export PATH="$HOME/.shorebird/bin:$PATH"

# Powerlevel10k
# source ~/powerlevel10k/powerlevel10k.zsh-theme
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# MySQL client
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"

if [[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" ]]; then
  unset PROMPT_EOL_MARK
fi

# DÉSACTIVÉ : carapace, avec zsh-autocomplete, cassait l'affichage de Zellij.
# export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
# source <(carapace _carapace)

# fzf-tab : menu de complétion (Tab) dans fzf. Doit venir après compinit et avant
# `fzf --zsh`, dont la complétion '**' retombe sur fzf-tab pour tout le reste.
source /opt/homebrew/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'   # groupes ; pas de codes couleur ici
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group '<' '>'

source <(fzf --zsh)

# deja : suggestion grisée prédictive (dossier courant, fréquence, commande
# précédente), à la place de zsh-autosuggestions (deja s'efface si les deux sont
# chargés). Après fzf-tab, qui doit être chargé avant les plugins qui enveloppent
# les widgets. Tab reste à fzf-tab : DEJA_CYCLE_KEY vide = pas de liaison.
# Revenir en arrière : remettre
#   source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
export DEJA_CYCLE_KEY=
if [[ -r "$HOME/.local/share/deja/init.zsh" ]]; then
  source "$HOME/.local/share/deja/init.zsh"
else
  eval "$(deja init zsh)"
fi

# Double Tab rapide : accepte la suggestion de deja au lieu d'ouvrir fzf-tab.
# Tab seul : complétion habituelle (fzf, puis fzf-tab), après 0,25 s d'attente
# uniquement quand une suggestion est affichée. Nom en _… : deja n'enveloppe pas
# ces widgets, POSTDISPLAY est donc encore intact ici. forward-char, lui, est
# enveloppé par deja (comme →) et accepte la suggestion en fin de ligne.
_tab_accept_or_complete() {
  local k
  if [[ -n $POSTDISPLAY ]] && read -k 1 -t 0.25 k; then
    if [[ $k == $'\t' ]]; then
      CURSOR=$#BUFFER
      zle forward-char
      return
    fi
    zle -U -- "$k"
  fi
  zle fzf-completion
}
zle -N _tab_accept_or_complete
bindkey '^I' _tab_accept_or_complete

# o [requête] : ouvre n'importe quel fichier dans VS Code, sans changer de dossier.
#   o ssh/config  -> ouvre directement ~/.ssh/config (chemin existant : pas de fzf)
#   o aero        -> fzf pré-rempli ; ~/.ssh, ~/.config et les dotfiles passent en premier
# Pas de recherche dans tout le home : .wine (liens en boucle), Library et les caches
# donnent 16M fichiers et 1min40. --scheme=history : à score égal, l'ordre de la liste
# (donc les dossiers de config) l'emporte.
o() {
  local q="$*" f
  for f in "$q" ~/"$q" ~/."$q"; do
    [[ -n $q && -f $f ]] && { code "$f"; return }
  done
  f=$( {
      fd --type f --hidden --max-depth 1 --base-directory ~ .
      fd --type f --hidden --base-directory ~ . .ssh .config
      fd --type f --hidden --exclude .git --exclude node_modules --base-directory ~ . Documents Desktop Downloads
    } 2>/dev/null | fzf --query="$q" --scheme=history \
        --preview "bat --color=always --style=numbers $HOME/{}" --preview-window=right,60%
  ) && code ~/"$f"
}

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"
