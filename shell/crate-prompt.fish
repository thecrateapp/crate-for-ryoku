# Crate for Ryoku: the Pure prompt in Crate's palette. Installed by Crate for Ryoku
# into ~/.config/fish/conf.d; uninstall.sh removes it. Global variables shadow
# Pure's universal defaults, so nothing of yours is rewritten: delete this file
# (or set your own value in config.fish) to go back.
test -f $__fish_config_dir/conf.d/pure.fish; or return 0

set -g pure_symbol_prompt //
set -g pure_color_primary 67e8f9        # the working directory
set -g pure_color_info 06b6d4           # git arrows and stash
set -g pure_color_mute 7e8084           # branch, user and host
set -g pure_color_success 06b6d4        # the prompt mark after a success
set -g pure_color_danger ef4444         # the prompt mark after a failure
set -g pure_color_warning f59e0b        # command duration
set -g pure_color_light f1f5f9
set -g pure_color_dark 0a0a0f
set -g pure_color_normal f1f5f9
