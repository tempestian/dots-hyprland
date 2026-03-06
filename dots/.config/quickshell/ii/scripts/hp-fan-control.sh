#!/bin/bash
# hp-fan-control.sh
# Yerleştir: ~/.config/quickshell/ii/scripts/hp-fan-control.sh
# chmod +x yapılacak
#
# Kullanım: bu script sudoers üzerinden NOPASSWD çalıştırılır,
# böylece QuickShell sysfs'e yazmak için şifre sormaz.

HWMON=$(find /sys/devices/platform/hp-wmi/hwmon -mindepth 1 -maxdepth 1 -name 'hwmon*' 2>/dev/null | head -1)
LED_PATH="/sys/class/leds/hp::kbd_backlight"

action="${1}"
shift

case "$action" in
    fan-mode)
        # $1 = 0|1|2
        echo "$1" | tee "$HWMON/pwm1_enable" > /dev/null
        ;;
    fan1-target)
        echo "$1" | tee "$HWMON/fan1_target" > /dev/null
        ;;
    fan2-target)
        echo "$1" | tee "$HWMON/fan2_target" > /dev/null
        ;;
    kbd-brightness)
        echo "$1" | tee "$LED_PATH/brightness" > /dev/null
        ;;
    kbd-color)
        # $1=R $2=G $3=B
        echo "$1 $2 $3" | tee "$LED_PATH/multi_intensity" > /dev/null
        ;;
    read-fans)
        echo "fan1=$(cat $HWMON/fan1_input 2>/dev/null)"
        echo "fan2=$(cat $HWMON/fan2_input 2>/dev/null)"
        echo "mode=$(cat $HWMON/pwm1_enable 2>/dev/null)"
        ;;
    *)
        echo "Bilinmeyen komut: $action" >&2
        exit 1
        ;;
esac
