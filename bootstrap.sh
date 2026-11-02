#!/usr/bin/env bash
# bootstrap.sh: install these dotfiles on a fresh Arch or CachyOS install, with nothing but curl.
#   curl -fsSL https://github.com/verycareful/dotfiles/releases/latest/download/bootstrap.sh | bash
#   ... | bash -s -- --minimal        no optional parts, no questions
#   ... | bash -s -- --all            every optional part that fits this machine, no questions
#   ... | bash -s -- --no-clamav      skip one optional part, ask about the rest (repeatable)
#   ... | bash -s -- --dry-run        print every command instead of running it
# DOTFILES_DIR sets where the repo is cloned (default ~/dotfiles).
#
# Run it as the desktop user, not root; it calls sudo itself. In order: a full system upgrade with git and
# base-devel, the clone checked out at the release, packages.txt, yay and the AUR packages, the optional parts
# that must come before ./install.sh (ClamAV), ./install.sh, then the other optional parts, Networking last
# since it replaces NetworkManager. Every question is asked before the first install, so the rest runs
# unattended.
#
# The copy attached to a release has RELEASE_TAG set to that release; run from a clone it uses the newest tag.
# Everything sits in main(), called on the last line, so a download cut short runs nothing.
set -euo pipefail

readonly RELEASE_TAG=""
readonly REPO_URL="https://github.com/verycareful/dotfiles"
readonly YAY_URL="https://aur.archlinux.org/yay-bin.git"
readonly AUR_PACKAGES=(waybar-git)          # the bar is set up against Waybar git master
readonly SUDO_REFRESH=60                    # seconds between sudo timestamp refreshes during the long steps
readonly AMD_VENDOR=0x1002

# optional parts, in the order they run; clamav goes before ./install.sh, which links the ClamAV user units
# only when ClamAV is installed, and network goes last
readonly PARTS=(clamav sddm perms snapper firewall hooks lact network)

DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
MODE=ask                                    # ask | all | minimal
DRY=""
SUDO_LOOP=""
declare -A SKIP=() WANT=()

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf 'bootstrap: %s\n' "$*" >&2; }
die()  { warn "$*"; exit 1; }
run()  { if [[ -n $DRY ]]; then printf '+ %s\n' "$*"; else "$@"; fi; }

usage() {
    cat <<'EOF'
curl -fsSL https://github.com/verycareful/dotfiles/releases/latest/download/bootstrap.sh | bash -s -- [options]
  --minimal     no optional parts, no questions
  --all         every optional part that fits this machine, no questions
  --no-<part>   skip one optional part, ask about the rest (repeatable)
  --dry-run     print every command instead of running it
Parts: clamav sddm perms snapper firewall hooks lact network. DOTFILES_DIR sets the clone folder (~/dotfiles).
EOF
}

describe() {
    case $1 in
        clamav)   echo "ClamAV on-access scanning: Downloads blocked until scanned, the rest of ~ watched" ;;
        sddm)     echo "SDDM login screen with the dotfiles theme (enabled if no display manager is set up)" ;;
        perms)    echo "permissions window, root side: clipboard blocking and the file access history" ;;
        snapper)  echo "btrfs snapshots of / around every update, bootable from GRUB" ;;
        firewall) echo "ufw firewall: inbound default-deny, KDE Connect allowed from the LAN" ;;
        hooks)    echo "pacman hooks: post-upgrade checks and weekly package cache cleaning" ;;
        lact)     echo "LACT AMD GPU control, plus the kernel parameter that unlocks overdrive (reboot after)" ;;
        network)  echo "systemd-networkd + iwd + resolved in place of NetworkManager" ;;
    esac
}

# a part is offered only where it can work
fits() {
    case $1 in
        snapper) [[ $(findmnt -no FSTYPE / 2>/dev/null) == btrfs && -d /boot/grub ]] ;;
        lact)    grep -qsx "$AMD_VENDOR" /sys/class/drm/card*/device/vendor ;;
        *)       true ;;
    esac
}

parse_args() {
    local a
    for a in "$@"; do
        case $a in
            --minimal) MODE=minimal ;;
            --all)     MODE=all ;;
            --dry-run) DRY=1 ;;
            --no-*)    local p=${a#--no-}
                       [[ " ${PARTS[*]} " == *" $p "* ]] || die "unknown part '$p' (parts: ${PARTS[*]})"
                       SKIP[$p]=1 ;;
            -h|--help) usage; exit 0 ;;
            *)         die "unknown option '$a' (see --help)" ;;
        esac
    done
}

preflight() {
    [[ $EUID -ne 0 ]] || die "run this as your desktop user, not root; it uses sudo where it needs to"
    command -v pacman >/dev/null || die "pacman not found: this is for Arch Linux and Arch-based systems"
    command -v sudo >/dev/null || die "sudo not found: as root, pacman -S sudo and add yourself to wheel"
    # curl | bash leaves stdin on the pipe; questions, sudo and makepkg need the terminal
    if { : </dev/tty; } 2>/dev/null; then
        exec </dev/tty
    elif [[ $MODE == ask ]]; then
        warn "no terminal to ask on: installing no optional parts (pass --all for every one)"
        MODE=minimal
    fi
}

choose_parts() {
    local p answer
    [[ $MODE == ask ]] && say "Optional parts (Enter = no)"
    for p in "${PARTS[@]}"; do
        fits "$p" || continue
        [[ -n ${SKIP[$p]:-} ]] && continue
        case $MODE in
            all)     WANT[$p]=1 ;;
            minimal) ;;
            ask)     read -rp "  $p: $(describe "$p")? [y/N] " answer
                     if [[ $answer == [yY]* ]]; then WANT[$p]=1; fi ;;
        esac
    done
}

keep_sudo() {
    [[ -n $DRY ]] && return
    sudo -v || die "sudo failed"
    while sleep "$SUDO_REFRESH"; do sudo -n true 2>/dev/null || exit; done &
    SUDO_LOOP=$!
    trap 'kill "$SUDO_LOOP" 2>/dev/null' EXIT
}

base_system() {
    say "Upgrading the system, with git and base-devel"
    run sudo pacman -Syu --needed --noconfirm git base-devel
}

clone_repo() {
    local ref
    if [[ -d $DIR/.git ]]; then
        [[ $(git -C "$DIR" remote get-url origin 2>/dev/null) == "$REPO_URL"* ]] \
            || die "$DIR is a git repo but not $REPO_URL; set DOTFILES_DIR to another folder"
        [[ -z $(git -C "$DIR" status --porcelain) ]] || die "$DIR has local changes; commit or move them first"
        say "Updating the clone in $DIR"
        run git -C "$DIR" fetch --tags --quiet origin
    elif [[ -e $DIR ]]; then
        die "$DIR exists and is not a clone of $REPO_URL; set DOTFILES_DIR to another folder"
    else
        say "Cloning into $DIR"
        run git clone --quiet "$REPO_URL" "$DIR"
    fi
    [[ -n $DRY && ! -d $DIR/.git ]] && { printf '+ git checkout %s\n' "${RELEASE_TAG:-<newest tag>}"; return; }
    ref=${RELEASE_TAG:-$(git -C "$DIR" tag --sort=-v:refname | head -1)}
    [[ -n $ref ]] || die "no release tag found in $DIR"
    say "Checking out release $ref"
    run git -C "$DIR" -c advice.detachedHead=false checkout --quiet "$ref"
}

# packages.txt holds several names per line, with # comment lines; pacman's `-` reads one name per line, so
# the names go in as arguments
repo_packages() {
    local pkgs=()
    if [[ -f $DIR/packages.txt ]]; then
        mapfile -t pkgs < <(grep -v '^[[:space:]]*#' "$DIR/packages.txt" | tr -s '[:space:]' '\n' | grep .)
    fi
    say "Installing packages.txt (${#pkgs[@]} packages)"
    if [[ -n $DRY && ${#pkgs[@]} -eq 0 ]]; then printf '+ sudo pacman -S --needed --noconfirm --asexplicit <packages.txt>\n'; return; fi
    (( ${#pkgs[@]} )) || die "no packages found in $DIR/packages.txt"
    run sudo pacman -S --needed --noconfirm --asexplicit "${pkgs[@]}"
}

aur_packages() {
    local build="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-bootstrap/yay-bin"
    if ! command -v yay >/dev/null; then
        if pacman -Si yay >/dev/null 2>&1; then
            say "Installing yay"
            run sudo pacman -S --needed --noconfirm yay
        else
            say "Building yay from the AUR"
            run rm -rf -- "$build"
            run git clone --quiet --depth 1 "$YAY_URL" "$build"
            if [[ -n $DRY ]]; then printf '+ (cd %s && makepkg -si --noconfirm)\n' "$build"
            else (cd "$build" && makepkg -si --noconfirm); fi
        fi
    fi
    say "Installing from the AUR: ${AUR_PACKAGES[*]}"
    run yay -S --needed --noconfirm --answerdiff None --answerclean None "${AUR_PACKAGES[@]}"
}

part() {
    [[ -n ${WANT[$1]:-} ]] || return 0
    say "Optional: $1"
    case $1 in
        clamav)   run sudo "$DIR/clamav/install-clamav.sh" ;;
        sddm)     run sudo pacman -S --needed --noconfirm sddm
                  run sudo "$DIR/sddm/install-sddm.sh"
                  [[ -e /etc/systemd/system/display-manager.service ]] || run sudo systemctl enable sddm.service ;;
        perms)    run sudo "$DIR/perms/install-perms.sh" ;;
        snapper)  run sudo "$DIR/snapper/install-snapper.sh" ;;
        firewall) run sudo "$DIR/firewall/install-firewall.sh" ;;
        hooks)    run sudo "$DIR/pacman/install-hooks.sh" ;;
        lact)     run sudo "$DIR/amd/install-lact.sh" ;;
        network)  run sudo "$DIR/network/install-network.sh" ;;
    esac
}

dotfiles() {
    say "Linking the dotfiles (./install.sh)"
    run "$DIR/install.sh"
}

finish() {
    say "Done"
    cat <<EOF
Reboot, then log in to Hyprland (uwsm-managed). Without a display manager, run 'uwsm start hyprland.desktop'
from the tty.
Left for you, since they depend on this machine:
  backup      sudo $DIR/backup/install-backup.sh LABEL=<drive label>, then: backup init
  ryzenadj    edit $DIR/amd/ryzen.conf for this CPU, yay -S ryzenadj, sudo $DIR/amd/install-ryzenadj.sh
$DIR is on a release tag; 'git -C $DIR switch main' follows the newest commits instead.
EOF
}

main() {
    parse_args "$@"
    preflight
    choose_parts
    keep_sudo
    base_system
    clone_repo
    repo_packages
    aur_packages
    part clamav
    dotfiles
    local p
    for p in "${PARTS[@]}"; do [[ $p == clamav ]] || part "$p"; done
    finish
}

main "$@"
