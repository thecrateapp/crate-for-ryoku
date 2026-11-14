# Sourced by the crate-mark tests that mount the panel. The panel draws the shell
# kit's Beam, Chip, IconButton and TrackLabel through Ryoku.PluginKit, which
# re-exports them from Ryoku's design-system Wave 5 on. RYOKU_SOURCE, a Ryoku
# checkout, puts its kit and plugin kit on the import path ahead of the installed
# ones; without it the installed plugin kit must already carry the re-exports.
# Call it before HOME moves to the scratch dir.
crate_mark_kit_path() {
    local work=$1 root
    if [[ -n ${RYOKU_SOURCE:-} ]]; then
        mkdir -p "$work/qml/Ryoku"
        ln -s "$RYOKU_SOURCE/ryoku/ui" "$work/qml/Ryoku/Ui"
        ln -s "$RYOKU_SOURCE/ryoku/shell/quickshell/plugins/kit" "$work/qml/Ryoku/PluginKit"
        export QML_IMPORT_PATH="$work/qml" QML2_IMPORT_PATH="$work/qml"
        return 0
    fi
    for root in "$HOME/.local/lib/qt6/qml" /usr/lib/qt6/qml; do
        grep -qs '^Beam ' "$root/Ryoku/PluginKit/qmldir" && return 0
    done
    echo "the installed Ryoku.PluginKit has no Beam: install a Ryoku with the kit re-exports or set RYOKU_SOURCE to a Ryoku checkout" >&2
    return 1
}
