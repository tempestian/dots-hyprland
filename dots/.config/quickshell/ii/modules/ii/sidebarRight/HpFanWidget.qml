pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    implicitHeight: mainCol.implicitHeight + 20
    clip: true

    property int  fanMode:    2
    property int  fan1Target: 2000
    property int  fan2Target: 2000
    property int  fan1Max:    6000
    property int  fan2Max:    6000
    property int  cpuTemp:    0
    property int  gpuTemp:    0
    property string hwmon:    ""

    readonly property color colDanger: Qt.rgba(1.00, 0.42, 0.42, 1)
    readonly property color colWarn:   Qt.rgba(1.00, 0.78, 0.30, 1)
    readonly property color colAccent: Appearance.colors.colPrimary

    readonly property string scriptPath: "/home/bayram/.config/quickshell/ii/scripts/hp-fan-control.sh"
    readonly property string tempsPath:  "/home/bayram/.config/quickshell/ii/scripts/read-temps.sh"

    // Komut kuyruğu
    property var cmdQueue: []
    property bool cmdRunning: false

    function runCmd(args) {
        cmdQueue.push(args)
        if (!cmdRunning) processQueue()
    }

    function processQueue() {
        if (cmdQueue.length === 0) { cmdRunning = false; return }
        cmdRunning = true
        var args = cmdQueue.shift()
        executor.command = args
        executor.running = true
    }

    Process {
        id: executor
        running: false
        command: ["echo", "init"]
        onRunningChanged: {
            if (!running) root.processQueue()
        }
    }

    // hwmon bul
    Process {
        id: procFindHwmon
        running: true
        command: ["bash", "-c", "find /sys/devices/platform/hp-wmi/hwmon -mindepth 1 -maxdepth 1 -name 'hwmon*' 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim()
                if (p !== "") {
                    root.hwmon = p
                    procReadState.running = true
                }
            }
        }
    }

    // Mevcut durumu oku
    Process {
    id: procReadState
    running: false
    property int lineIdx: 0
    command: ["bash", "-c",
        "if [ -f /home/bayram/.config/quickshell/ii/fan-state ]; then " +
        "  cat /home/bayram/.config/quickshell/ii/fan-state; " +
        "else " +
        "  echo '2 2000 2000'; " +
        "fi; " +
        "cat /sys/devices/platform/hp-wmi/hwmon/hwmon*/fan1_max 2>/dev/null; " +
        "cat /sys/devices/platform/hp-wmi/hwmon/hwmon*/fan2_max 2>/dev/null"
    ]
    stdout: SplitParser {
        onRead: line => {
            var parts = line.trim().split(" ")
            if (procReadState.lineIdx === 0 && parts.length === 3) {
                var m  = parseInt(parts[0])
                var f1 = parseInt(parts[1])
                var f2 = parseInt(parts[2])
                if (!isNaN(m))  root.fanMode    = m
                if (!isNaN(f1)) root.fan1Target = f1
                if (!isNaN(f2)) root.fan2Target = f2
            } else {
                var v = parseInt(line.trim())
                if (procReadState.lineIdx === 1 && v > 0) root.fan1Max = v
                if (procReadState.lineIdx === 2 && v > 0) root.fan2Max = v
            }
            procReadState.lineIdx++
        }
    }
    onRunningChanged: if (running) lineIdx = 0
}

    // Sıcaklık
    Process {
        id: procTemps
        running: false
        command: ["bash", root.tempsPath]
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split("=")
                if (parts.length === 2) {
                    var val = Math.round(parseFloat(parts[1]))
                    if (parts[0] === "cpu" && val > 0) root.cpuTemp = val
                    if (parts[0] === "gpu" && val > 0) root.gpuTemp = val
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            procTemps.running = false
            procTemps.running = true
        }
    }
    
    Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: {
        if (root.fanMode === 0) {
            root.runCmd(["sudo", root.scriptPath, "fan-mode", "0"])
        } else if (root.fanMode === 1) {
            root.runCmd(["sudo", root.scriptPath, "fan-mode", "1"])
            root.runCmd(["sudo", root.scriptPath, "fan1-target", String(root.fan1Target)])
            root.runCmd(["sudo", root.scriptPath, "fan2-target", String(root.fan2Target)])
        }
         fanMode === 2
    }
}
    // Fan kontrol fonksiyonları
    // YENİ:
    function saveState() {
    runCmd(["bash", "-c",
        "echo '" + fanMode + " " + fan1Target + " " + fan2Target +
        "' > /home/bayram/.config/quickshell/ii/fan-state"
    ])
    }
    
    function setFanMode(m) {
    fanMode = m
    runCmd(["sudo", root.scriptPath, "fan-mode", String(m)])
    saveState()
    }

    function setFan1(v) {
    fan1Target = Math.min(v, fan1Max)
    runCmd(["sudo", root.scriptPath, "fan1-target", String(fan1Target)])
    saveState()
    }
    
    function setFan2(v) {
    fan2Target = Math.min(v, fan2Max)
    runCmd(["sudo", root.scriptPath, "fan2-target", String(fan2Target)])
    saveState()
    }

    // ======================================
    // UI
    // ======================================
    ColumnLayout {
        id: mainCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10

        // Başlık
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            MaterialSymbol {
                text: "mode_fan"
                iconSize: Appearance.font.pixelSize.larger
                color: root.fanMode === 0 ? root.colDanger
                     : root.fanMode === 1 ? root.colAccent
                     : Appearance.colors.colOnLayer1
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                RotationAnimator on rotation {
                    from: 0; to: 360; running: true; loops: Animation.Infinite
                    duration: 3000
                }
            }
            StyledText {
                text: Translation.tr("Fan Control")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                Layout.fillWidth: true
            }
            Rectangle {
                radius: height / 2
                implicitHeight: modeLabel.implicitHeight + 6
                implicitWidth:  modeLabel.implicitWidth + 14
                color: root.fanMode === 0 ? Qt.rgba(root.colDanger.r, root.colDanger.g, root.colDanger.b, 0.18)
                     : root.fanMode === 1 ? Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.18)
                     : Qt.rgba(root.colWarn.r, root.colWarn.g, root.colWarn.b, 0.18)
                Behavior on color { ColorAnimation { duration: 200 } }
                StyledText {
                    id: modeLabel
                    anchors.centerIn: parent
                    text: root.fanMode === 0 ? Translation.tr("MAX")
                        : root.fanMode === 1 ? Translation.tr("MANUAL")
                        : Translation.tr("AUTO")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.fanMode === 0 ? root.colDanger
                         : root.fanMode === 1 ? root.colAccent
                         : root.colWarn
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Mod Butonları
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { label: Translation.tr("Max"),    icon: "local_fire_department", mode: 0 },
                    { label: Translation.tr("Manual"), icon: "tune",                  mode: 1 },
                    { label: Translation.tr("Auto"),   icon: "thermostat_auto",       mode: 2 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 36
                    radius: Appearance.rounding.small
                    property color modeColor: modelData.mode === 0 ? root.colDanger
                                            : modelData.mode === 1 ? root.colAccent
                                            : root.colWarn
                    color: root.fanMode === modelData.mode
                           ? Qt.rgba(modeColor.r, modeColor.g, modeColor.b, 0.20)
                           : Appearance.colors.colLayer2
                    border.color: root.fanMode === modelData.mode ? modeColor : "transparent"
                    border.width: 1.5
                    Behavior on color        { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.fanMode === modelData.mode ? parent.parent.modeColor : Appearance.colors.colOnLayer2
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.fanMode === modelData.mode ? parent.parent.modeColor : Appearance.colors.colOnLayer2
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setFanMode(modelData.mode)
                    }
                }
            }
        }

        // Sıcaklık kartları
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true; height: 32; radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 6
                    MaterialSymbol {
                        text: "memory"; iconSize: Appearance.font.pixelSize.normal
                        color: root.cpuTemp >= 90 ? root.colDanger : root.cpuTemp >= 70 ? root.colWarn : root.colAccent
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    StyledText { text: "CPU"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                    StyledText {
                        text: root.cpuTemp + "°C"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium
                        color: root.cpuTemp >= 90 ? root.colDanger : root.cpuTemp >= 70 ? root.colWarn : Appearance.colors.colOnLayer1
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; height: 32; radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 6
                    MaterialSymbol {
                        text: "developer_board"; iconSize: Appearance.font.pixelSize.normal
                        color: root.gpuTemp >= 90 ? root.colDanger : root.gpuTemp >= 75 ? root.colWarn : root.colAccent
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    StyledText { text: "GPU"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1; Layout.fillWidth: true }
                    StyledText {
                        text: root.gpuTemp + "°C"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium
                        color: root.gpuTemp >= 90 ? root.colDanger : root.gpuTemp >= 75 ? root.colWarn : Appearance.colors.colOnLayer1
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }

        // Fan 1
        FanRow {
            label: "Fan 1"; targetRpm: root.fan1Target; maxRpm: root.fan1Max
            manual: root.fanMode === 1; Layout.fillWidth: true
            onMoved: (v) => root.setFan1(v)
        }

        // Fan 2
        FanRow {
            label: "Fan 2"; targetRpm: root.fan2Target; maxRpm: root.fan2Max
            manual: root.fanMode === 1; Layout.fillWidth: true
            onMoved: (v) => root.setFan2(v)
        }

        Item { height: 2 }
    }

    component FanRow: ColumnLayout {
        id: fanRow
        property string label: "Fan"
        property int targetRpm: 2000
        property int maxRpm: 6000
        property bool manual: false
        signal moved(int val)
        spacing: 4

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            visible: fanRow.manual
            opacity: fanRow.manual ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            StyledText {
                text: fanRow.label; font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1; Layout.preferredWidth: 40
            }
            StyledSlider {
                id: fanSlider; Layout.fillWidth: true
                configuration: StyledSlider.Configuration.M; stopIndicatorValues: []
                from: 500; to: fanRow.maxRpm; stepSize: 100; value: fanRow.targetRpm
                onMoved: fanRow.moved(Math.round(fanSlider.value))
            }
            StyledText {
                text: Math.round(fanSlider.value); font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 42
            }
        }
    }
}
