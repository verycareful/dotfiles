# fish — "Harbour" shell config. Aliases/abbrs live in conf.d/.
# greeting: fastfetch (logo + system info), only for interactive shells. A terminal wide enough for the large
# logo (152 by 21, the height of the info, so it starts on the first row) beside the info gets it; narrower ones
# keep the small logo from the config.
set -g greeting_wide_columns 220
function fish_greeting
    command -q fastfetch; or return
    if test $COLUMNS -ge $greeting_wide_columns
        fastfetch --logo-type file --logo ~/.config/fastfetch/sonnenplatz-wide.txt --logo-padding-top 0
    else
        fastfetch
    end
end

# ── paths ────────────────────────────────────────────────────
fish_add_path -g ~/.local/bin
fish_add_path -g ~/.cargo/bin
fish_add_path -g ~/.local/share/gradle-8.10.2/bin   # pinned: the version kern's CI uses
fish_add_path -g ~/Android/Sdk/platform-tools        # adb

# ── environment ──────────────────────────────────────────────
set -gx EDITOR  micro
set -gx VISUAL  code
set -gx PAGER   less
set -gx LESS    -R
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx BAT_THEME dotfiles
# Android: Gradle 8.10.2 runs on JDK 17..23, so not the system JDK 24 and not
# Android Studio's bundled JBR (25). jdk21-openjdk from pacman.
set -gx JAVA_HOME    /usr/lib/jvm/java-21-openjdk
set -gx ANDROID_HOME ~/Android/Sdk
# starship ignores XDG_CONFIG_HOME, so point it at the file explicitly
set -q XDG_CONFIG_HOME; and set -gx STARSHIP_CONFIG $XDG_CONFIG_HOME/starship.toml; or set -gx STARSHIP_CONFIG ~/.config/starship.toml

# ── prompt / tools (only in interactive shells) ─────────────
if status is-interactive
    starship init fish | source
    fzf --fish | source          # ctrl+r history, ctrl+t files, alt+c dirs
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
end
