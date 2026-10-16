import QtQuick
import QtQuick.Layouts
import qs.theme

Canvas {
    id: root

    property var values: []
    property real ceiling: 0
    property bool fitRange: false
    property color color: Theme.primary

    Layout.fillWidth: true
    implicitHeight: 40

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = root.values ?? [];
        if (v.length < 2)
            return;

        let lo = 0;
        let hi = root.ceiling > 0 ? root.ceiling : Math.max(...v, 1);
        if (root.fitRange) {
            lo = Math.min(...v);
            hi = Math.max(...v);
            const pad = Math.max((hi - lo) * 0.15, 1);
            lo -= pad;
            hi += pad;
        }

        const x = i => i / (v.length - 1) * width;
        const y = val => height - 2 - (Math.min(val, hi) - lo) / (hi - lo) * (height - 4);

        ctx.beginPath();
        ctx.moveTo(0, height);
        for (let i = 0; i < v.length; i++)
            ctx.lineTo(x(i), y(v[i]));
        ctx.lineTo(width, height);
        ctx.closePath();
        const grad = ctx.createLinearGradient(0, 0, 0, height);
        grad.addColorStop(0, Qt.rgba(root.color.r, root.color.g, root.color.b, 0.35));
        grad.addColorStop(1, Qt.rgba(root.color.r, root.color.g, root.color.b, 0));
        ctx.fillStyle = grad;
        ctx.fill();

        ctx.beginPath();
        for (let i = 0; i < v.length; i++)
            i === 0 ? ctx.moveTo(x(i), y(v[i])) : ctx.lineTo(x(i), y(v[i]));
        ctx.strokeStyle = root.color;
        ctx.lineWidth = 1.5;
        ctx.stroke();
    }
}
