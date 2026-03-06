pragma Singleton
import QtQuick

// HP WMI Fan & RGB Control Service
// Yerleştir: ~/.config/quickshell/ii/services/HpFanService.qml
//
// KURULUM GEREKSİNİMİ - sudoers ayarı:
// sudo visudo -f /etc/sudoers.d/hp-fan-control
// İçeriği:
//   %wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/platform/hp-wmi/hwmon/hwmon*/pwm1_enable
//   %wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/platform/hp-wmi/hwmon/hwmon*/fan1_target
//   %wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/platform/hp-wmi/hwmon/hwmon*/fan2_target
//   %wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/leds/hp::kbd_backlight/multi_intensity
//   %wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/leds/hp::kbd_backlight/brightness
//   YA DA daha basit: kullanıcıadın ALL=(ALL) NOPASSWD: /home/kullanicin/.config/quickshell/ii/scripts/hp-fan-control.sh
QtObject {
    id: root

    // --- Mevcut durumlar ---
    property int fanMode: 2          // 0=Max, 1=Manual, 2=Auto
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan1Target: 2000
    property int fan2Target: 2000
    property int fan1Max: 6000
    property int fan2Max: 6000

    property int kbdBrightness: 128
    property int kbdRed: 255
    property int kbdGreen: 255
    property int kbdBlue: 255

    property bool available: false
    property string hwmonPath: ""

    // --- iç state ---
    property var _proc: null

    // hwmon path'i bul
    function findHwmonPath() {
        _runShell("find /sys/devices/platform/hp-wmi/hwmon -maxdepth 1 -name 'hwmon*' 2>/dev/null | head -1", function(out) {
            var path = out.trim()
            if (path !== "") {
                hwmonPath = path
                available = true
                _readAll()
            } else {
                available = false
            }
        })
    }

    function _readAll() {
        if (!available) return
        _readFile(hwmonPath + "/pwm1_enable", function(v) { fanMode = parseInt(v) || 2 })
        _readFile(hwmonPath + "/fan1_input",  function(v) { fan1Rpm = parseInt(v) || 0 })
        _readFile(hwmonPath + "/fan2_input",  function(v) { fan2Rpm = parseInt(v) || 0 })
        _readFile(hwmonPath + "/fan1_target", function(v) { fan1Target = parseInt(v) || 2000 })
        _readFile(hwmonPath + "/fan2_target", function(v) { fan2Target = parseInt(v) || 2000 })
        _readFile(hwmonPath + "/fan1_max",    function(v) { if (parseInt(v) > 0) fan1Max = parseInt(v) })
        _readFile(hwmonPath + "/fan2_max",    function(v) { if (parseInt(v) > 0) fan2Max = parseInt(v) })
        _readFile("/sys/class/leds/hp::kbd_backlight/brightness", function(v) { kbdBrightness = parseInt(v) || 0 })
        _readFile("/sys/class/leds/hp::kbd_backlight/multi_intensity", function(v) {
            var parts = v.trim().split(" ")
            if (parts.length >= 3) {
                kbdRed   = parseInt(parts[0]) || 255
                kbdGreen = parseInt(parts[1]) || 255
                kbdBlue  = parseInt(parts[2]) || 255
            }
        })
    }

    // --- Kontrol fonksiyonları ---

    // fanMode: 0=Max, 1=Manual, 2=Auto
    function setFanMode(mode) {
        fanMode = mode
        _writeFile(hwmonPath + "/pwm1_enable", String(mode))
    }

    function setFan1Target(rpm) {
        fan1Target = Math.min(rpm, fan1Max)
        if (fanMode === 1) {
            _writeFile(hwmonPath + "/fan1_target", String(fan1Target))
        }
    }

    function setFan2Target(rpm) {
        fan2Target = Math.min(rpm, fan2Max)
        if (fanMode === 1) {
            _writeFile(hwmonPath + "/fan2_target", String(fan2Target))
        }
    }

    function setKbdBrightness(val) {
        kbdBrightness = val
        _writeFile("/sys/class/leds/hp::kbd_backlight/brightness", String(val))
    }

    function setKbdColor(r, g, b) {
        kbdRed = r; kbdGreen = g; kbdBlue = b
        _writeFile("/sys/class/leds/hp::kbd_backlight/multi_intensity", r + " " + g + " " + b)
    }

    // --- Yardımcı: sudo tee ile sysfs'e yaz ---
    function _writeFile(path, value) {
        // hp-fan-control.sh scripti üzerinden çalıştır (NOPASSWD sudoers gerektirir)
        var cmd = "echo '" + value + "' | sudo tee " + path + " > /dev/null 2>&1"
        _runShell(cmd, null)
    }

    // --- Yardımcı: dosya oku ---
    function _readFile(path, callback) {
        _runShell("cat " + path + " 2>/dev/null", callback)
    }

    // Process havuzu - seri çalıştırma
    function _runShell(cmd, callback) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { running: false }', root)
        proc.command = ["bash", "-c", cmd]
        if (callback) {
            proc.stdoutReady.connect(function() {
                callback(proc.stdout)
            })
        }
        proc.running = true
    }

    // Periyodik okuma (RPM gerçek zamanlı güncelleme)
    property var _pollTimer: Timer {
        interval: 2000
        running: root.available
        repeat: true
        onTriggered: {
            root._readFile(root.hwmonPath + "/fan1_input", function(v) { root.fan1Rpm = parseInt(v) || 0 })
            root._readFile(root.hwmonPath + "/fan2_input", function(v) { root.fan2Rpm = parseInt(v) || 0 })
        }
    }

    Component.onCompleted: {
        findHwmonPath()
    }
}
