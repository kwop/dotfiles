# zoxide, commun à belaz et agent. Module chargé en dernier (recommandation zoxide)
if command -v zoxide &> /dev/null; then
  if [[ -z "$CLAUDECODE" ]]; then
    # Shell normal : zoxide remplace cd
    eval "$(zoxide init --cmd cd zsh)"

    # Priorité au plus proche : `cd inf` depuis hmrkt/ va dans hmrkt/infra même si
    # l'infra d'un autre projet a un meilleur score. La recherche part du dossier
    # courant puis remonte d'un parent à la fois. À chaque niveau : d'abord la base
    # zoxide limitée à ce niveau (meilleur score), puis, pour un mot seul, les
    # sous-dossiers directs réellement présents (même jamais visités, donc absents
    # de la base) ; ce second essai se limite au dossier courant et au dépôt git
    # qui le contient. Sans résultat avant la racine, zoxide reprend la main avec
    # son classement global habituel.
    # Depuis hmrkt/infra, `cd helm` trouve donc hmrkt/helm avant paramedic/helm.
    # Comparer avec le comportement d'origine : ZOXIDE_NEAREST=0 cd helm
    # (ou `export ZOXIDE_NEAREST=0` pour tout le shell).
    __zoxide_z_near() {
      # Laissés à zoxide : désactivé, sans argument, chemin existant, -, +N/-N, options
      if [[ $ZOXIDE_NEAREST == 0 ]] || (( $# == 0 )) || [[ $1 == -* || $1 == +<-> ]] \
        || { (( $# == 1 )) && [[ -d $1 ]] }; then
        __zoxide_z "$@"
        return
      fi
      setopt localoptions extendedglob
      local base=$PWD result top= d=$PWD k
      local -a kids matches
      # Tous les résultats zoxide, meilleur score d'abord, en un seul appel (sans
      # --base-dir, absent avant zoxide 0.10) ; le filtrage par niveau se fait ici.
      matches=( ${(f)"$(command zoxide query --list -- "$@" 2>/dev/null)"} )
      matches=( ${matches:#$PWD} )
      # Sommet du dépôt git englobant (le plus haut, pour sortir des sous-modules)
      while [[ $d != / ]]; do [[ -e $d/.git ]] && top=$d; d=${d:h}; done
      while [[ $base != / ]]; do
        result=${matches[(r)${(b)base}/*]}
        if [[ -n $result ]]; then
          __zoxide_cd "$result"
          return
        fi
        if (( $# == 1 )) && [[ $base == $PWD || ( -n $top && ( $base == $top || $base == $top/* ) ) ]]; then
          # Nom qui commence par le mot, sinon qui le contient ; le plus court gagne
          kids=( $base/(#i)${(b)1}*(N/) )
          (( $#kids )) || kids=( $base/(#i)*${(b)1}*(N/) )
          kids=( ${kids:#$PWD} )
          if (( $#kids )); then
            result=$kids[1]
            for k in $kids; do (( $#k < $#result )) && result=$k; done
            __zoxide_cd "$result"
            return
          fi
        fi
        base=${base:h}
      done
      __zoxide_z "$@"
    }
    function cd() { __zoxide_z_near "$@" }
  else
    # Shell Claude : zoxide utilise 'z', cd reste natif (évite bug snapshot)
    eval "$(zoxide init zsh)"
  fi
fi
