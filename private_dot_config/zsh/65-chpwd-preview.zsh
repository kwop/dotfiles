# Aperçu du dossier à chaque cd (liste eza + tableau git), propre à belaz : hors liste blanche
# de .chezmoiignore, donc jamais déployé sur agent. Dépend d'eza (Brewfile) et de git.
#   - liste eza en colonnes, entrées touchées par git surlignées
#   - tableau git : modifiés / ajoutés / supprimés / non suivis, mêmes teintes
#
# Ne s'affiche que dans un shell que TU utilises : jamais dans un script,
# un `zsh -c`, une sortie redirigée, ni sous Claude Code / Codex (cf. _chpwd_preview_allowed).
#
# Réglages (à mettre avant le source) :
#   CHPWD_PREVIEW=0|force               0 = désactivé, force = ignore les garde-fous (tests)
#   CHPWD_PREVIEW_STYLE=tint|frame|gutter  marquage des entrées git (défaut : tint)
#   CHPWD_PREVIEW_TABLE=compact|full    tableau git sans ou avec ligne de pied (défaut : compact)
#   CHPWD_PREVIEW_MAX_ROWS=8            lignes max pour la liste
#   CHPWD_PREVIEW_GIT_ROWS=6            lignes max par colonne git
#   CHPWD_PREVIEW_HYPERLINK=1           noms cliquables (OSC 8, Cmd+clic dans Ghostty), 0 pour couper
#   CHPWD_PREVIEW_BG_M|A|D|U="r;g;b"   teinte de fond par statut (ex. CHPWD_PREVIEW_BG_U="140;140;158")
#   CHPWD_PREVIEW_HIDDEN=1              fichiers cachés affichés (.git reste masqué), 0 pour couper
#   CHPWD_PREVIEW_SKIP_USERS=(agent)    utilisateurs pour qui le hook ne s'active jamais
#   CHPWD_PREVIEW_AGENT_VARS=(...)      variables d'env qui signalent un agent

# Rien à faire hors shell interactif : on n'enregistre même pas le hook
[[ -o interactive || ${CHPWD_PREVIEW:-} == force ]] || return 0

autoload -Uz add-zsh-hook

(( ${+CHPWD_PREVIEW_SKIP_USERS} )) || typeset -ga CHPWD_PREVIEW_SKIP_USERS=(agent)
(( ${+CHPWD_PREVIEW_AGENT_VARS} )) || typeset -ga CHPWD_PREVIEW_AGENT_VARS=(
  CLAUDECODE CLAUDE_CODE_ENTRYPOINT          # Claude Code
  CODEX_SANDBOX CODEX_SANDBOX_NETWORK_DISABLED  # Codex CLI
  CURSOR_AGENT GEMINI_CLI                    # autres agents
)

# Vrai seulement pour une session tapée à la main dans un vrai terminal
_chpwd_preview_allowed() {
  [[ ${CHPWD_PREVIEW:-1} == force ]] && return 0
  [[ ${CHPWD_PREVIEW:-1} == 0 ]] && return 1
  [[ -o interactive ]]           || return 1   # script, zsh -c
  [[ -z $ZSH_EXECUTION_STRING ]] || return 1   # zsh -ic '…' (ce que font certains agents)
  [[ -t 0 && -t 1 ]]             || return 1   # entrée/sortie redirigée ou pipe
  [[ $TERM != (dumb|) ]]         || return 1
  (( ${CHPWD_PREVIEW_SKIP_USERS[(Ie)${USER:-$USERNAME}]} )) && return 1
  local v; for v in $CHPWD_PREVIEW_AGENT_VARS; do [[ -n ${(P)v} ]] && return 1; done
  return 0
}

# Affiche un tableau d'éléments (déjà colorés) en colonnes, ordre vertical comme ls.
# $1 = largeur max, $2 = lignes max, reste = éléments
_chpwd_grid() {
  emulate -L zsh -o extendedglob
  local -i width=$1 maxrows=$2; shift 2
  local -a items=("$@") w cw
  local -i n=$#items i c r m k j total cmax
  (( n )) || return
  local s more
  for s in $items; do
    s=${s//$'\e'\[[0-9;]#m/}; s=${s//$'\e]8;;'[^$'\e']#$'\e\\'/}   # couleurs, puis liens OSC 8
    w+=(${(m)#s})
  done

  # on cherche le plus de colonnes possible ; si ça dépasse maxrows,
  # on ne garde que ce qui tient et la dernière case devient « … +N »
  cmax=$(( width / 3 )); (( cmax > n )) && cmax=n; (( cmax < 1 )) && cmax=1
  for (( c = cmax; c >= 1; c-- )); do
    r=$(( (n + c - 1) / c )); m=n
    if (( r > maxrows )); then r=maxrows m=$(( c * maxrows - 1 )); fi
    (( m < 1 )) && m=1
    cw=(); total=$(( 2 * (c - 1) ))
    for (( i = 1; i <= m; i++ )); do
      k=$(( (i - 1) / r + 1 )); (( w[i] > ${cw[k]:-0} )) && cw[k]=$w[i]
    done
    if (( m < n )); then
      k=$(( m / r + 1 )); j=$(( 3 + ${#$(( n - m ))} ))
      (( j > ${cw[k]:-0} )) && cw[k]=$j
    fi
    for i in $cw; do (( total += i )); done
    (( total <= width || c == 1 )) && break
  done
  if (( m < n )); then
    more=$'\e[2m'"… +$(( n - m ))"$'\e[0m'
    items=("${(@)items[1,m]}" "$more"); w=("${(@)w[1,m]}" $(( 3 + ${#$(( n - m ))} )))
    n=$#items
  fi

  local line
  for (( i = 1; i <= r; i++ )); do
    line=''
    for (( k = 1; k <= $#cw; k++ )); do
      j=$(( (k - 1) * r + i ))
      (( j > n )) && break
      line+=$items[j]
      (( k < $#cw && j + r <= n )) && line+=${(l:$(( cw[k] - w[j] + 2 )):: :)}
    done
    print -r -- $line
  done
}

_chpwd_preview() {
  _chpwd_preview_allowed || return
  emulate -L zsh -o extendedglob
  local -i cols=${COLUMNS:-80}
  local style=${CHPWD_PREVIEW_STYLE:-tint}
  local ESC=$'\e' R=$'\e[0m' DIM=$'\e[2m'
  local -A fg=( M $'\e[33m' A $'\e[32m' D $'\e[31m' U $'\e[1;97m' )
  # mêmes teintes pour le surlignage du ls et les en-têtes du tableau git ;
  # « non suivi » plus clair que les autres : un gris foncé disparaît sur un fond Ghostty transparent
  local -A bg=(
    M $'\e[48;2;'${CHPWD_PREVIEW_BG_M:-66;60;20}m
    A $'\e[48;2;'${CHPWD_PREVIEW_BG_A:-22;62;36}m
    D $'\e[48;2;'${CHPWD_PREVIEW_BG_D:-72;26;30}m
    U $'\e[48;2;'${CHPWD_PREVIEW_BG_U:-110;110;128}m
  )
  local B=$'\e[90m'      # couleur des bordures
  local -A sym=( M '●' A '✚' D '✖' U '?' )
  local -A rank=( U 1 A 2 M 3 )   # départage en cas d'égalité

  # --- statut git, limité au dossier courant -------------------------------
  local -A top            # entrée de premier niveau -> M/A/U
  local -A cnt            # "entrée:statut" -> nombre de fichiers
  local -a gM gA gD gU
  local ingit=0 line xy p t k ins=0 del=0
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    ingit=1
    for line in ${(f)"$(git -c color.status=false status --short --untracked-files=normal -- . 2>/dev/null)"}; do
      xy=${line[1,2]} p=${line[4,-1]}
      [[ $p == *' -> '* ]] && p=${p##* -> }
      p=${p%/}
      case $xy in
        '??')  k=U; gU+=$p ;;
        *D*)   k=D; gD+=$p ;;
        A?)    k=A; gA+=$p ;;
        *)     k=M; gM+=$p ;;
      esac
      t=${p%%/*}
      [[ $k == D && $t == $p ]] && continue      # fichier supprimé : absent du ls
      [[ $k == D ]] && k=M                        # dossier qui a perdu un fichier
      (( cnt[$t:$k]++ ))
    done
    # un dossier prend la couleur majoritaire de son contenu (égalité : M > A > U)
    local key cur
    for key in ${(k)cnt}; do
      t=${key%:*} k=${key##*:} cur=${top[$t]:-}
      if [[ -z $cur ]] || (( cnt[$key] > cnt[$t:$cur] ||
            (cnt[$key] == cnt[$t:$cur] && rank[$k] > rank[$cur]) )); then
        top[$t]=$k
      fi
    done
    local ns=( ${=$(git diff HEAD --numstat -- . 2>/dev/null | awk '{i+=$1;d+=$2} END{print i+0, d+0}')} )
    ins=${ns[1]:-0} del=${ns[2]:-0}
  fi

  # --- liste eza -----------------------------------------------------------
  local -a opts=(-1 --group-directories-first --git-ignore --no-quotes)
  [[ ${CHPWD_PREVIEW_HIDDEN:-1} != 0 ]] && opts+=(-a)
  local -a link=(); [[ ${CHPWD_PREVIEW_HYPERLINK:-1} != 0 ]] && link=(--hyperlink)
  local -a names colored items
  names=( ${(f)"$(command eza $opts --color=never --icons=never -- . 2>/dev/null)"} )
  colored=( ${(f)"$(command eza $opts $link --color=always --icons=auto -- . 2>/dev/null)"} )
  local -i i
  local e s
  for (( i = 1; i <= $#names; i++ )); do
    # en -1, eza affiche « lien -> cible » : on ne garde que le nom
    e=$colored[i]; [[ $names[i] == *' -> '* ]] && e="${e%% ($ESC\[[0-9;]#m)#->*}$R"
    s=${top[${names[i]%% -> *}]:-}
    if [[ -z $s ]]; then
      case $style in
        frame) items+=" $e " ;;
        gutter) items+="  $e" ;;
        *) items+=" $e " ;;
      esac
    else
      case $style in
        frame)  items+="$fg[$s]▕$R$e$fg[$s]▏$R" ;;
        gutter) items+="$fg[$s]▎$R $e" ;;
        tint)   items+="$bg[$s] ${e//$'\e'\[(0|)m/$R$bg[$s]} $R" ;;
      esac
    fi
  done
  _chpwd_grid $cols ${CHPWD_PREVIEW_MAX_ROWS:-8} $items

  (( ingit )) || return

  # --- tableau git ---------------------------------------------------------
  local -i total=$(( $#gM + $#gA + $#gD + $#gU ))
  print
  if (( ! total )); then
    print -r -- "$B── ${R}git · rien à signaler$B ──$R"
    return
  fi

  local -a groups=() heads=()
  (( $#gM )) && groups+=M && heads+="$sym[M] modifiés $#gM"
  (( $#gA )) && groups+=A && heads+="$sym[A] ajoutés $#gA"
  (( $#gD )) && groups+=D && heads+="$sym[D] supprimés $#gD"
  (( $#gU )) && groups+=U && heads+="$sym[U] non suivis $#gU"

  local -i ng=$#groups maxr=${CHPWD_PREVIEW_GIT_ROWS:-6}
  local -i g h rows=0 shown sum inner wi room
  local -a list shownc colw
  local f d b cell plain out sumtxt sumplain

  # largeur naturelle de chaque colonne, puis on rogne la plus large tant que ça déborde
  for (( g = 1; g <= ng; g++ )); do
    list=( ${(P)${:-g$groups[g]}} )
    shown=$#list; (( shown > maxr )) && shown=$(( maxr - 1 ))
    shownc[g]=$shown
    (( h = shown + ($#list > shown) )); (( h > rows )) && rows=$h
    colw[g]=${(m)#heads[g]}
    for f in ${list[1,shown]}; do (( ${(m)#f} > colw[g] )) && colw[g]=${(m)#f}; done
    (( colw[g] > 36 )) && colw[g]=36
  done
  while :; do
    sum=$(( 3 * ng + 1 )); for h in $colw; do (( sum += h )); done
    (( sum <= cols )) && break
    wi=1; for (( g = 2; g <= ng; g++ )); do (( colw[g] > colw[wi] )) && wi=$g; done
    (( colw[wi] <= 12 )) && break
    (( colw[wi]-- ))
  done
  inner=$(( sum - 2 ))

  # trait horizontal : $1 gauche, $2 jonction, $3 droite
  _chpwd_rule() {
    local o=$B$1
    for (( g = 1; g <= ng; g++ )); do
      o+=${(l:$(( colw[g] + 2 ))::─:)}
      (( g < ng )) && o+=$2
    done
    print -r -- "$o$3$R"
  }

  _chpwd_rule ╭ ┬ ╮
  out=$B│$R
  for (( g = 1; g <= ng; g++ )); do
    out+="$bg[$groups[g]]$fg[$groups[g]] $heads[g]${(l:$(( colw[g] - ${(m)#heads[g]} )):: :)} $R$B│$R"
  done
  print -r -- $out
  _chpwd_rule ├ ┼ ┤

  for (( h = 1; h <= rows; h++ )); do
    out=$B│$R
    for (( g = 1; g <= ng; g++ )); do
      list=( ${(P)${:-g$groups[g]}} ); shown=$shownc[g]
      cell='' plain=''
      if (( h <= shown )); then
        f=$list[h] d=''
        b=${f:t}; [[ $f == */* ]] && d=${f:h}/
        # trop long : on garde le nom du fichier, on raccourcit le dossier par la gauche
        if (( ${(m)#d} + ${(m)#b} > colw[g] )); then
          room=$(( colw[g] - ${(m)#b} - 1 ))
          if (( room > 0 )); then d="…${d[-room,-1]}"
          else d='' b="…${b[-(colw[g]-1),-1]}"; fi
        fi
        plain="$d$b"; cell="$DIM$d$R$b"
        if [[ $link == --hyperlink && $groups[g] != D ]]; then
          cell=$'\e]8;;file://'"${PWD}/${list[h]}"$'\e\\'"$cell"$'\e]8;;\e\\'
        fi
      elif (( h == shown + 1 && $#list > shown )); then
        plain="… +$(( $#list - shown ))"; cell="$DIM$plain$R"
      fi
      out+=" $cell${(l:$(( colw[g] - ${(m)#plain} )):: :)} $B│$R"
    done
    print -r -- $out
  done

  if [[ ${CHPWD_PREVIEW_TABLE:-compact} == compact ]]; then
    # pas de pied : « +x −y » glissé à droite dans la bordure du bas
    sumplain=" +$ins −$del "
    out=$B╰
    for (( g = 1; g <= ng; g++ )); do
      if (( g == ng && colw[g] + 2 >= ${(m)#sumplain} + 1 )); then
        out+="${(l:$(( colw[g] + 2 - ${(m)#sumplain} - 1 ))::─:)}$R $fg[A]+$ins$R $fg[D]−$del$R $B─"
      else
        out+=${(l:$(( colw[g] + 2 ))::─:)}
      fi
      (( g < ng )) && out+=┴
    done
    print -r -- "$out╯$R"
  else
    sumplain="$total changement(s) · +$ins −$del"
    sumtxt="$DIM$total changement(s) ·$R $fg[A]+$ins$R $fg[D]−$del$R"
    _chpwd_rule ├ ┴ ┤
    print -r -- "$B│$R $sumtxt${(l:$(( inner - 2 - ${(m)#sumplain} )):: :)} $B│$R"
    print -r -- "$B╰${(l:$inner::─:)}╯$R"
  fi
  unfunction _chpwd_rule
}

add-zsh-hook chpwd _chpwd_preview
