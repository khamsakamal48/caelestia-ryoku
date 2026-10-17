# Interactive shells only: SDDM starts the desktop through `fish -l`, so an
# unguarded conda hook put conda's bin/ (its own dbus-monitor, which cannot find
# the system bus) ahead of /usr/bin for Hyprland and every session service.
if status is-interactive
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -f $HOME/miniconda3/bin/conda
    eval $HOME/miniconda3/bin/conda "shell.fish" "hook" $argv | source
else
    if test -f "$HOME/miniconda3/etc/fish/conf.d/conda.fish"
        . "$HOME/miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "$HOME/miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<
end

