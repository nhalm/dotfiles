import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.theme

PopupWindow {
    id: popup

    required property Item chip
    property bool chipHovered: false
    property bool hold: false
    default property alias content: body.data
    readonly property int gap: 8

    readonly property bool pointerInside: chipHovered || cardHover.hovered
    property bool armed: false

    function toggle() { visible = !visible; }

    onPointerInsideChanged: {
        if (pointerInside) {
            armed = true;
            closeTimer.stop();
        } else if (visible && armed) {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 400
        onTriggered: if (!popup.pointerInside && !popup.hold) popup.visible = false
    }

    anchor.window: chip.QsWindow.window
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    onVisibleChanged: {
        armed = pointerInside;
        if (!visible) {
            closeTimer.stop();
            return;
        }
        const win = chip.QsWindow.window;
        const origin = chip.mapToItem(chip.QsWindow.contentItem, 0, chip.height);
        const centred = origin.x + chip.width / 2 - implicitWidth / 2;
        anchor.rect.x = Math.round(Math.max(8, Math.min(centred, win.width - implicitWidth - 8)));
        anchor.rect.y = Math.round(origin.y);
    }

    implicitWidth: 360
    implicitHeight: card.implicitHeight + gap
    color: "transparent"
    grabFocus: false

    HyprlandFocusGrab {
        windows: [popup]
        active: popup.visible
        onCleared: popup.visible = false
    }

    property real shown: visible ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

    Item {
        anchors.fill: parent

        HoverHandler { id: cardHover }

        Rectangle {
            id: card
            width: parent.width
            implicitHeight: body.implicitHeight + 28
            y: popup.gap + (1 - popup.shown) * -10
            opacity: popup.shown
            radius: Theme.radius
            color: Theme.island
            border.width: 1
            border.color: Theme.islandBorder

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: 14
                spacing: 14
            }
        }
    }
}
