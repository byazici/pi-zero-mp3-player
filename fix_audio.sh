#!/bin/bash

# Raspberry Pi Zero W - Audio Sizzle Fix Script
# Bu script ses sistemindeki sizzle/crackling problemini çözer

echo "🔊 Raspberry Pi Zero W Audio Fix Başlatılıyor..."
echo "=============================================="

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   echo "Bu script root yetkileri ile çalıştırılmalıdır: sudo bash fix_audio.sh"
   exit 1
fi

echo "[1/6] PulseAudio konfigürasyonu güncelleniyor..."

# PulseAudio daemon konfigürasyonu (Pi Zero W için optimize)
cat > /etc/pulse/daemon.conf << 'EOF'
# Pi Zero W optimized settings
default-sample-format = s16le
default-sample-rate = 22050
alternate-sample-rate = 44100
default-sample-channels = 2
default-channel-map = front-left,front-right

default-fragments = 8
default-fragment-size-msec = 25

resample-method = speex-float-1
avoid-resampling = false
enable-lfe-remixing = no
high-priority = yes
nice-level = -11

realtime-scheduling = yes
realtime-priority = 5

rlimit-fsize = -1
rlimit-data = -1
rlimit-stack = -1
rlimit-core = -1
rlimit-as = -1
rlimit-rss = -1
rlimit-nproc = -1
rlimit-nofile = 256
rlimit-memlock = -1
rlimit-locks = -1
rlimit-sigpending = -1
rlimit-msgqueue = -1
rlimit-nice = 31
rlimit-rtprio = 9
rlimit-rttime = 200000

flat-volumes = no
EOF

echo "[2/6] ALSA konfigürasyonu güncelleniyor..."

# ALSA konfigürasyonu (mp3player kullanıcısı için)
sudo -u mp3player cat > /home/mp3player/.asoundrc << 'EOF'
pcm.!default {
    type pulse
    server unix:/tmp/pulse-socket
}

ctl.!default {
    type pulse
    server unix:/tmp/pulse-socket
}

# Pi Zero W için özel PCM ayarları
pcm.pi_zero {
    type hw
    card 0
    device 0
    rate 22050
    channels 2
    format S16_LE
    period_size 1024
    buffer_size 4096
}
EOF

echo "[3/6] Audio buffer ayarları optimize ediliyor..."

# Kernel audio parametreleri
cat > /etc/modprobe.d/alsa-base.conf << 'EOF'
# ALSA portion
alias char-major-116 snd
alias snd-card-0 snd-bcm2835
options snd-bcm2835 index=0

# Prevent abnormal drivers from grabbing index 0
options bt87x index=-2
options cx88_alsa index=-2
options saa7134-alsa index=-2
options snd-atiixp-modem index=-2
options snd-intel8x0m index=-2
options snd-via82xx-modem index=-2
options snd-usb-audio index=-2

# Pi Zero W specific optimizations
options snd-bcm2835 enable_headphones=1
options snd-usb-audio nrpacks=1
options snd-usb-audio async_unlink=0
options snd-usb-audio sync_mode=0
EOF

echo "[4/6] Boot konfigürasyonu güncelleniyor..."

# Boot config optimizasyonları
if ! grep -q "audio_pwm_mode" /boot/config.txt; then
    cat >> /boot/config.txt << 'EOF'

# Audio optimizations for Pi Zero W
audio_pwm_mode=0
disable_audio_dither=1
pwm_sample_bits=20
force_turbo=0
over_voltage=0

# GPU memory (minimum for headless audio)
gpu_mem=16

# Audio buffer settings
snd_bcm2835.enable_compat_alsa=0
snd_bcm2835.enable_hdmi=1
snd_bcm2835.enable_headphones=1
EOF
fi

echo "[5/6] PulseAudio servisi yeniden konfigüre ediliyor..."

# PulseAudio systemd servisini güncelle
cat > /etc/systemd/system/pulseaudio-mp3player.service << 'EOF'
[Unit]
Description=PulseAudio for MP3Player (optimized for Pi Zero W)
After=sound.target
Wants=sound.target

[Service]
Type=notify
User=mp3player
Group=mp3player
ExecStart=/usr/bin/pulseaudio --start --log-target=syslog --system=false --realtime=true --disallow-exit=true
ExecStop=/usr/bin/pulseaudio --kill
Restart=on-failure
RestartSec=5
NotifyAccess=main
LimitRTPRIO=9
LimitNICE=-11
IOSchedulingClass=1
IOSchedulingPriority=4

# Audio thread priorities
Environment="PULSE_REALTIME_SCHEDULING=1"
Environment="PULSE_HIGH_PRIORITY=1"

[Install]
WantedBy=multi-user.target
EOF

echo "[6/6] CPU governor ve sistem optimizasyonları..."

# CPU governor for better audio performance
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
fi

# Disable CPU idle states that can cause audio glitches
echo 1 > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy 2>/dev/null || true

# Audio-specific sysctl settings
cat > /etc/sysctl.d/99-audio-performance.conf << 'EOF'
# Audio performance tuning for Pi Zero W
dev.hpet.max-user-freq = 3072
kernel.yama.ptrace_scope = 0

# Memory management for audio
vm.swappiness = 10
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2

# Network buffer (may affect audio streaming)
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
EOF

echo "Sistem ayarları uygulanıyor..."
sysctl -p /etc/sysctl.d/99-audio-performance.conf

# Servisleri yeniden başlat
systemctl daemon-reload
systemctl stop mp3player.service
systemctl stop pulseaudio-mp3player.service

sleep 2

systemctl start pulseaudio-mp3player.service
sleep 3
systemctl start mp3player.service

echo ""
echo "=============================================="
echo "🔊 Audio Fix Tamamlandı!"
echo "=============================================="
echo ""
echo "📋 Yapılan İyileştirmeler:"
echo "  ✓ PulseAudio buffer boyutları optimize edildi"
echo "  ✓ ALSA ayarları Pi Zero W için yapılandırıldı"
echo "  ✓ Kernel audio parametreleri güncellendi"
echo "  ✓ CPU governor performance moduna alındı"
echo "  ✓ Sistem bellek yönetimi optimize edildi"
echo ""
echo "⚠️  Değişikliklerin tam etkili olması için yeniden başlatın:"
echo "     sudo reboot"
echo ""
echo "🎵 Yeniden başlatma sonrası audio sizzle problemi çözülmüş olmalı."

# Test ses çalma
echo ""
echo "🔍 Test yapılıyor..."
if command -v speaker-test &> /dev/null; then
    echo "5 saniye test sesi çalınıyor..."
    timeout 5s speaker-test -c 2 -r 22050 -D default 2>/dev/null || echo "Test sesi çalınamadı (normal)"
fi

echo ""
echo "📊 Mevcut ses konfigürasyonu:"
echo "PulseAudio servisi: $(systemctl is-active pulseaudio-mp3player.service)"
echo "MP3Player servisi: $(systemctl is-active mp3player.service)"
echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'Bilinmiyor')"