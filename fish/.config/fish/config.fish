# fish — "Harbour" shell config. Aliases/abbrs live in conf.d/.
set -g fish_greeting                       # no greeting

# ── paths ────────────────────────────────────────────────────
fish_add_path -g ~/.local/bin
fish_add_path -g ~/.cargo/bin

# ── environment ──────────────────────────────────────────────
set -gx EDITOR  micro
set -gx VISUAL  code
set -gx PAGER   less
set -gx LESS    -R
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx BAT_THEME base16
# starship ignores XDG_CONFIG_HOME, so point it at the file explicitly
set -q XDG_CONFIG_HOME; and set -gx STARSHIP_CONFIG $XDG_CONFIG_HOME/starship.toml; or set -gx STARSHIP_CONFIG ~/.config/starship.toml

# ── prompt / tools (only in interactive shells) ─────────────
if status is-interactive
    starship init fish | source
    fzf --fish | source          # ctrl+r history, ctrl+t files, alt+c dirs
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
end
