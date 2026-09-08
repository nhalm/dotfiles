pragma Singleton
import Quickshell
import QtQuick

Singleton {
    // "centered": three islands hugging their content, floating with gaps.
    // "full":     one bar spanning the screen, sections spread across it.
    property string layout: "centered"
}
