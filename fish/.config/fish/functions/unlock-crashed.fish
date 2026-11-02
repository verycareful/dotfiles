function unlock-crashed --description 'Run from a tty: unlock a Hyprland session whose lockscreen crashed'
    # The lockscreen wrapper goes first, or it would start a fresh hyprlock the moment this one dies.
    # It runs as `bash .../lockscreen`, so it is matched by command line, not by process name.
    pkill -f '/\.local/bin/lockscreen$'
    pkill -9 -x hyprlock
    hyprctl --instance 0 eval 'hl.clear_crashed_lockscreen()'
end
