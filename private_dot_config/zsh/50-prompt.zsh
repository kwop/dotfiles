# Prompt, commun à belaz et agent : starship à gauche, utilisateur courant à droite.
# Configs starship/zellij : fixées explicitement dans le home, pour écraser une valeur
# héritée d'un shell parent qui pointerait encore vers /Users/Shared
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
export ZELLIJ_CONFIG_FILE="$HOME/.config/zellij/config.kdl"
eval "$(starship init zsh)"

# Utilisateur courant à droite du prompt, sur une couleur propre à chaque compte
# (partagé entre belaz et agent). À sourcer APRÈS `starship init zsh`, qui pose son
# propre RPROMPT. Couleur dérivée d'un hash du nom : stable d'une session à l'autre,
# calculée une fois au démarrage (starship ne sait pas styler selon l'utilisateur).
# Couleurs = numéros de la palette du terminal (5 violet, 6 cyan, 11 jaune vif,
# 3 jaune, 2 vert, 4 bleu, 13 rose ; 1 rouge pour root) : elles suivent le thème Ghostty.
() {
  local -a couleurs=(5 6 11 3 2 4 13)
  local fond c
  local -i h=0
  if (( EUID == 0 )); then
    fond=1
  else
    for c in ${(s::)USERNAME}; do (( h = (h * 31 + #c) % 2147483647 )); done
    fond=${couleurs[h % $#couleurs + 1]}
  fi
  RPROMPT="%B%F{black}%K{$fond} "$''" %n %k%f%b"
}
