import QtQuick
import Ryoku.Ui.Singletons

// The palette card: the search field, the tabs, the grouped results and the
// key hints. Main.qml (`host`) owns the query, the tab and the selection.
Rectangle {
    id: card

    property var host: null
    readonly property var groups: card.host ? card.host.groups : []

    width: Tokens.px(640)
    implicitHeight: layout.implicitHeight
    radius: Tokens.radius
    // translucent like the shell's other panels; Hyprland frosts the launcher
    // layer behind it (ignore_alpha keeps the frost inside the card)
    color: Qt.rgba(Tokens.paperLift.r, Tokens.paperLift.g, Tokens.paperLift.b, 0.82)
    border.width: Tokens.border
    border.color: Tokens.line
    clip: true

    readonly property var sectionNames: ({
        apps: "Apps", files: "Files", recent: "Recent", crate: "Crate",
        artists: "Artists", albums: "Albums", tracks: "Tracks"
    })

    function focusField() {
        field.forceActiveFocus();
    }

    // keep the selected result inside the scroll window
    function reveal(target) {
        const p = target.mapToItem(results.contentItem, 0, 0);
        if (p.y < results.contentY)
            results.contentY = p.y;
        else if (p.y + target.height > results.contentY + results.height)
            results.contentY = p.y + target.height - results.height;
    }

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: layout
        width: parent.width

        // ── search field ────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Tokens.px(52)

            Glyph {
                id: lens
                visible: !card.host || card.host.tab !== "crate"
                name: "magnifer"
                tint: Tokens.inkDim
                size: Tokens.px(18)
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
            }
            Rectangle {
                id: chip
                visible: !lens.visible
                height: Tokens.px(20)
                width: chipText.implicitWidth + Tokens.s2 * 2
                radius: Tokens.px(4)
                color: Look.mark
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: "CRATE"
                    color: Tokens.paper
                    font.family: Look.navFont
                    font.pixelSize: Tokens.fTiny
                    font.letterSpacing: Look.trackNav
                }
            }

            TextInput {
                id: field
                anchors {
                    left: lens.visible ? lens.right : chip.right
                    leftMargin: Tokens.s3
                    right: parent.right
                    rightMargin: Tokens.s4
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                color: Tokens.ink
                selectionColor: Look.mark
                selectedTextColor: Tokens.paper
                font.family: Tokens.ui
                font.pixelSize: Tokens.fValue
                clip: true
                Component.onCompleted: field.forceActiveFocus()
                onTextEdited: field.text = card.host.edited(field.text)

                Connections {
                    target: card.host
                    function onQueryChanged() {
                        if (field.text !== card.host.query)
                            field.text = card.host.query;
                    }
                }

                Keys.onPressed: event => {
                    if (card.host.key(event, field.text))
                        event.accepted = true;
                }

                Text {
                    visible: field.text.length === 0
                    text: card.host && card.host.tab === "crate" ? I18n.tr("Search your library") : I18n.tr("Search apps, files and Crate")
                    color: Tokens.inkFaint
                    font: field.font
                }
            }

            Rectangle {
                width: parent.width
                height: Tokens.px(1)
                anchors.bottom: parent.bottom
                color: Look.mark
            }
        }

        // ── tabs ────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Tokens.px(34)

            Row {
                anchors { left: parent.left; leftMargin: Tokens.s4; top: parent.top; bottom: parent.bottom }
                spacing: Tokens.s5

                Repeater {
                    model: [
                        { id: "all", label: "All" }, { id: "apps", label: "Apps" },
                        { id: "files", label: "Files" }, { id: "crate", label: "Crate" },
                        { id: "rec", label: "Rec" }
                    ]
                    delegate: Item {
                        id: tabItem
                        required property var modelData
                        readonly property bool on: card.host && card.host.tab === tabItem.modelData.id
                        width: tabText.implicitWidth
                        height: parent.height

                        Text {
                            id: tabText
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr(tabItem.modelData.label).toUpperCase()
                            color: tabItem.on ? Look.mark : (tabMouse.containsMouse ? Look.hoverInk : Tokens.inkFaint)
                            font.family: Look.navFont
                            font.pixelSize: Tokens.fTiny
                            font.letterSpacing: Look.trackNav
                        }
                        Rectangle {
                            visible: tabItem.on
                            width: parent.width
                            height: Tokens.px(2)
                            anchors.bottom: parent.bottom
                            color: Look.mark
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.host.setTab(tabItem.modelData.id);
                                field.forceActiveFocus();
                            }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: Tokens.px(1)
                anchors.bottom: parent.bottom
                color: Tokens.line
            }
        }

        // ── results ─────────────────────────────────────────────────────
        Flickable {
            id: results
            width: parent.width
            height: Math.min(groupsColumn.implicitHeight, Tokens.px(460))
            contentHeight: groupsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: groupsColumn
                width: results.width
                bottomPadding: card.groups.length ? Tokens.s2 : 0

                Repeater {
                    model: card.groups
                    delegate: Column {
                        id: group
                        required property var modelData
                        required property int index
                        readonly property int offset: card.host.offsets[group.index] || 0
                        width: groupsColumn.width

                        Item {
                            width: parent.width
                            height: Tokens.px(30)
                            Text {
                                anchors { left: parent.left; leftMargin: Tokens.s4; bottom: parent.bottom; bottomMargin: Tokens.s1 }
                                text: I18n.tr(card.sectionNames[group.modelData.section] || group.modelData.section).toUpperCase()
                                color: Look.caption
                                font.family: Look.navFont
                                font.pixelSize: Tokens.fTiny
                                font.letterSpacing: Look.trackNav
                            }
                            Text {
                                visible: group.modelData.section === "crate" && card.host.tab !== "crate"
                                anchors { right: parent.right; rightMargin: Tokens.s4; bottom: parent.bottom; bottomMargin: Tokens.s1 }
                                text: I18n.tr("cr ⇥ for more")
                                color: Tokens.inkFaint
                                font.family: Look.navFont
                                font.pixelSize: Tokens.fTiny
                                font.letterSpacing: Look.trackNav
                            }
                        }

                        // albums in Crate's own view: a grid of covers
                        Grid {
                            id: grid
                            visible: group.modelData.section === "albums"
                            columns: 4
                            spacing: Tokens.s3
                            leftPadding: Tokens.s4
                            rightPadding: Tokens.s4
                            topPadding: Tokens.s1
                            bottomPadding: Tokens.s2
                            readonly property real cell: (groupsColumn.width - Tokens.s4 * 2 - Tokens.s3 * 3) / 4

                            Repeater {
                                model: group.modelData.section === "albums" ? group.modelData.rows : []
                                delegate: AlbumTile {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    width: grid.cell
                                    item: tile.modelData
                                    live: card.host.selected === group.offset + tile.index
                                    onLiveChanged: if (live) card.reveal(tile)
                                    onHovered: card.host.selected = group.offset + tile.index
                                    onPicked: card.host.run(tile.modelData, "")
                                }
                            }
                        }

                        Repeater {
                            model: group.modelData.section === "albums" ? [] : group.modelData.rows
                            delegate: ResultRow {
                                id: line
                                required property var modelData
                                required property int index
                                width: group.width
                                item: line.modelData
                                live: card.host.selected === group.offset + line.index
                                showTag: group.modelData.section === "crate"
                                showDuration: group.modelData.section === "tracks"
                                onLiveChanged: if (live) card.reveal(line)
                                onHovered: card.host.selected = group.offset + line.index
                                onPicked: card.host.run(line.modelData, "")
                            }
                        }
                    }
                }
            }
        }

        Item {
            visible: card.host && card.host.text.length > 0 && card.groups.length === 0
            width: parent.width
            height: Tokens.px(64)
            Text {
                anchors.centerIn: parent
                text: card.host && card.host.tab === "crate" && card.host.crateSearching ? I18n.tr("Searching your library")
                    : I18n.tr("No results")
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: Tokens.fBody
            }
        }

        // ── key hints and count ─────────────────────────────────────────
        Item {
            width: parent.width
            height: Tokens.px(36)

            Rectangle {
                width: parent.width
                height: Tokens.px(1)
                color: Tokens.line
            }
            Row {
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                spacing: Tokens.s2
                Repeater {
                    model: card.host ? card.host.hints : []
                    delegate: Rectangle {
                        id: hint
                        required property string modelData
                        height: Tokens.px(20)
                        width: hintText.implicitWidth + Tokens.s2 * 2
                        radius: Tokens.px(4)
                        color: "transparent"
                        border.width: Tokens.border
                        border.color: Tokens.line
                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: hint.modelData
                            color: Tokens.inkDim
                            font.family: Look.navFont
                            font.pixelSize: Tokens.fTiny
                        }
                    }
                }
            }
            Text {
                anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                text: card.host ? card.host.tally : ""
                color: Tokens.inkFaint
                font.family: Look.navFont
                font.pixelSize: Tokens.fTiny
                font.letterSpacing: Look.trackNav
            }
        }
    }
}
