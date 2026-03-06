pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Klavye RGB Kontrolü
// Yerleştir: ~/.config/quickshell/ii/modules/ii/sidebarRight/KbdRgbWidget.qml

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    implicitHeight: mainCol.implicitHeight + 20
    clip: true

    property int kbdR:      0
    property int kbdG:      0
    property int kbdB:      255
    property int kbdBright: 128

    readonly property color colAccent: Appearance.colors.colPrimary
    readonly property color currentColor: Qt.rgba(kbdR/255, kbdG/255, kbdB/255, 1.0)

    // Hazır renk paleti
    readonly property var palette: [
        { name: "Beyaz",    r: 255, g: 255, b: 255 },
        { name: "Kırmızı",  r: 255, g: 0,   b: 0   },
        { name: "Turuncu",  r: 255, g: 80,  b: 0   },
        { name: "Sarı",     r: 255, g: 200, b: 0   },
        { name: "Yeşil",    r: 0,   g: 255, b: 0   },
        { name: "Camgöbeği",r: 0,   g: 255, b: 200 },
        { name: "Mavi",     r: 0,   g: 100, b: 255 },
        { name: "Mor",      r: 150, g: 0,   b: 255 },
        { name: "Pembe",    r: 255, g: 0,   b: 150 },
        { name: "Kapalı",   r: 0,   g: 0,   b: 0   },
    ]

    // Seçili palet indexi (-1 = özel)
    property int selectedPalette: 6  // Mavi default

    // Başlangıç değerlerini oku
    FileView {
        id: fvBright
        path: "/sys/class/leds/hp::kbd_backlight/brightness"
        onTextChanged: { var v = parseInt(text); if (!isNaN(v)) root.kbdBright = v }
    }
    FileView {
        id: fvColor
        path: "/sys/class/leds/hp::kbd_backlight/multi_intensity"
        onTextChanged: {
            var p = text.trim().split(" ")
            if (p.length >= 3) {
                root.kbdR = parseInt(p[0]) || 0
                root.kbdG = parseInt(p[1]) || 0
                root.kbdB = parseInt(p[2]) || 0
            }
        }
    }

    Component.onCompleted: {
        fvBright.reload()
        fvColor.reload()
    }

    // Script üzerinden yaz (sudoers :: path sorununu aşar)
    function runScript(args) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { running: false }', root)
        proc.command = ["sudo", "/home/bayram/.config/quickshell/ii/scripts/hp-fan-control.sh"].concat(args)
        proc.running = true
    }

    function applyColor(r, g, b) {
        kbdR = r; kbdG = g; kbdB = b
        runScript(["kbd-color", String(r), String(g), String(b)])
    }

    function applyBrightness(v) {
        kbdBright = v
        runScript(["kbd-brightness", String(v)])
    }

    // ======================================
    // UI
    // ======================================
    ColumnLayout {
        id: mainCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        // --- Başlık ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "keyboard"
                iconSize: Appearance.font.pixelSize.larger
                color: root.kbdBright === 0
                       ? Appearance.colors.colOnLayer1
                       : root.currentColor
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            StyledText {
                text: Translation.tr("Keyboard RGB")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                Layout.fillWidth: true
            }

            // Renk önizleme
            Rectangle {
                width: 48; height: 22; radius: height / 2
                color: root.kbdBright === 0 ? Appearance.colors.colLayer2 : root.currentColor
                Behavior on color { ColorAnimation { duration: 200 } }
                StyledText {
                    anchors.centerIn: parent
                    text: root.kbdBright === 0 ? "OFF"
                        : "#%1%2%3"
                          .arg(root.kbdR.toString(16).padStart(2,'0').toUpperCase())
                          .arg(root.kbdG.toString(16).padStart(2,'0').toUpperCase())
                          .arg(root.kbdB.toString(16).padStart(2,'0').toUpperCase())
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: (root.kbdR + root.kbdG + root.kbdB) > 350 ? "#000" : "#fff"
                }
            }
        }

        // --- Parlaklık ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: kbdBright === 0 ? "brightness_empty" : "brightness_high"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
                Layout.preferredWidth: 22
            }

            StyledSlider {
                id: brightSlider
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.M
                stopIndicatorValues: []
                from: 0; to: 255; stepSize: 1
                value: root.kbdBright
                onMoved: root.applyBrightness(Math.round(brightSlider.value))
            }

            StyledText {
                text: Math.round(brightSlider.value)
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 28
            }
        }

        // --- Renk Paleti ---
        StyledText {
            text: Translation.tr("Renk")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }

        // Renk grid - 5'li satırlar
        Grid {
            columns: 5
            spacing: 6
            Layout.fillWidth: true

            Repeater {
                model: root.palette
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: (mainCol.width - 6 * 4) / 5
                    height: width
                    radius: Appearance.rounding.small

                    // Kapalı için çizgili görünüm
                    color: modelData.r === 0 && modelData.g === 0 && modelData.b === 0
                           ? Appearance.colors.colLayer2
                           : Qt.rgba(modelData.r/255, modelData.g/255, modelData.b/255, 1.0)

                    // Seçili halkası
                    border.color: root.selectedPalette === index
                                  ? Appearance.colors.colOnLayer1
                                  : "transparent"
                    border.width: 2.5

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Kapalı ikonu
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: modelData.r === 0 && modelData.g === 0 && modelData.b === 0
                        text: "power_settings_new"
                        iconSize: parent.height * 0.5
                        color: Appearance.colors.colOnLayer1
                    }

                    // Seçim efekti
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "white"
                        opacity: 0
                        id: ripple
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedPalette = index
                            root.applyColor(modelData.r, modelData.g, modelData.b)
                            ripple.opacity = 0.3
                            rippleTimer.start()
                        }
                    }

                    Timer {
                        id: rippleTimer
                        interval: 150
                        onTriggered: ripple.opacity = 0
                    }
                }
            }
        }

        Item { height: 2 }
    }
}
