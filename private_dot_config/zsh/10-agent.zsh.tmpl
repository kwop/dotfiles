# Config propre au compte agent : Homebrew (installé et possédé par belaz), outils dans
# ~/.local/bin, ssh-agent persistant avec la clé GitLab du compte de service.
# Déployée uniquement pour agent : voir .chezmoiignore.
eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$PATH"

if [[ -o interactive ]]; then
    SSH_AGENT_DIR="$HOME/.ssh/agent"
    SSH_AUTH_SOCK="$SSH_AGENT_DIR/socket"

    mkdir -p "$SSH_AGENT_DIR"
    chmod 700 "$SSH_AGENT_DIR"

    export SSH_AUTH_SOCK

    # Is there an ssh-agent listening on our persistent socket?
    if ! ssh-add -l >/dev/null 2>&1; then
        rm -f "$SSH_AUTH_SOCK"

        ssh-agent \
            -a "$SSH_AUTH_SOCK" \
            -t 14400 \
            >/dev/null
    fi

    GITLAB_KEY="$HOME/.ssh/gitlab-sa-agent"

    # Is our GitLab key loaded?
    KEY_FP="$(ssh-keygen -lf "$GITLAB_KEY.pub" | awk '{print $2}')"

    if ! ssh-add -l 2>/dev/null | grep -Fq "$KEY_FP"; then
        echo "Unlock GitLab SSH key:"
        ssh-add -t 4h "$GITLAB_KEY"
    fi
fi
