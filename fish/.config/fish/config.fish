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

# ── prompt / tools (only in interactive shells) ─────────────
if status is-interactive
    starship init fish | source
    fzf --fish | source          # ctrl+r history, ctrl+t files, alt+c dirs
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
    set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border=sharp --color=bg+:#111a30,fg+:#e4e8f4,hl:#ff8c32,hl+:#ff8c32,pointer:#ff8c32,prompt:#3b5fe0,border:#1a2547,info:#5d6784,marker:#5fc98a'
end
