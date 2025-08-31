#!/bin/bash

# Raspberry Pi Zero W - Audio System Debug Script
# Bu script ses sistemindeki problemleri teşhis eder ve çözüm önerir

echo "🔍 Raspberry Pi Audio System Debug"
echo "=================================="

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    if [ $2 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

echo -e "\n${BLUE}[1] Sistem Bilgileri${NC}"
echo "Pi Model: $(cat /proc/cpuinfo | grep 'Model' | head -1)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"

echo -e "\n${BLUE}[2] Ses Kartları${NC}"
if lsusb | grep -i audio > /dev/null; then
    print_status "USB Ses Kartı bulundu" 0
    lsusb | grep -i audio
else
    print_status "USB Ses Kartı bulunamadı" 1
fi

echo "Mevcut ses cihazları:"
aplay -l 2>/dev/null || echo "Ses cihazı bulunamadı"

echo -e "\n${BLUE}[3] ALSA Durumu${NC}"
if command -v alsamixer &> /dev/null; then
    print_status "ALSA kurulu" 0
else
    print_status "ALSA kurulu değil" 1
fi

# ALSA konfigürasyonu kontrolü
if [ -f "/home/mp3player/.asoundrc" ]; then
    print_status ".asoundrc dosyası mevcut" 0
else
    print_status ".asoundrc dosyası eksik" 1
fi

echo -e "\n${BLUE}[4] PulseAudio Durumu${NC}"
if systemctl is-active --quiet pulseaudio-mp3player.service; then
    print_status "PulseAudio servisi çalışıyor" 0
else
    print_status "PulseAudio servisi çalışmıyor" 1
    echo "Servis durumu:"
    systemctl status pulseaudio-mp3player.service --no-pager -l
fi

# PulseAudio mp3player kullanıcısı için kontrol
if sudo -u mp3player pulseaudio --check; then
    print_status "mp3player için PulseAudio çalışıyor" 0
else
    print_status "mp3player için PulseAudio çalışmıyor" 1
fi

echo -e "\n${BLUE}[5] Python ve Pygame${NC}"
if sudo -u mp3player /opt/mp3player/venv/bin/python -c "import pygame" 2>/dev/null; then
    print_status "Pygame import edilebiliyor" 0
else
    print_status "Pygame import edilemiyor" 1
fi

# Pygame mixer test
echo "Pygame mixer test:"
sudo -u mp3player /opt/mp3player/venv/bin/python << 'EOF'
import pygame
import sys

try:
    pygame.mixer.init()
    print("✓ Pygame mixer başlatıldı")
    
    # Get mixer info
    freq, size, channels = pygame.mixer.get_init()
    print(f"  Frequency: {freq} Hz")
    print(f"  Sample size: {size} bits")
    print(f"  Channels: {channels}")
    
    pygame.mixer.quit()
    sys.exit(0)
except Exception as e:
    print(f"✗ Pygame mixer hatası: {e}")
    sys.exit(1)
EOF

print_status "Pygame mixer test" $?

echo -e "\n${BLUE}[6] MP3Player Servisi${NC}"
if systemctl is-active --quiet mp3player.service; then
    print_status "MP3Player servisi çalışıyor" 0
else
    print_status "MP3Player servisi çalışmıyor" 1
    echo "Servis durumu:"
    systemctl status mp3player.service --no-pager -l
fi

echo -e "\n${BLUE}[7] Dosya İzinleri${NC}"
if [ -d "/opt/mp3player" ]; then
    print_status "/opt/mp3player dizini mevcut" 0
    echo "Dizin sahibi: $(stat -c '%U:%G' /opt/mp3player)"
    echo "İzinler: $(stat -c '%a' /opt/mp3player)"
else
    print_status "/opt/mp3player dizini eksik" 1
fi

if [ -d "/opt/mp3player/uploads" ]; then
    print_status "uploads dizini mevcut" 0
    echo "uploads sahibi: $(stat -c '%U:%G' /opt/mp3player/uploads)"
    echo "uploads izinleri: $(stat -c '%a' /opt/mp3player/uploads)"
else
    print_status "uploads dizini eksik" 1
fi

echo -e "\n${BLUE}[8] Log Analizi${NC}"
echo "Son 10 MP3Player log girişi:"
journalctl -u mp3player.service --no-pager -n 10 | tail -10

if grep -i "mixer not initialized" /var/log/mp3player/app.log 2>/dev/null | tail -5; then
    echo -e "${RED}Mixer initialization hataları bulundu!${NC}"
else
    print_status "Log'da mixer hatası bulunamadı" 0
fi

echo -e "\n${BLUE}[9] Çözüm Önerileri${NC}"
echo "================================="

# USB ses kartı önerisi
if ! lsusb | grep -i audio > /dev/null; then
    echo -e "${YELLOW}Öneri 1:${NC} USB ses kartı kullanın"
    echo "Pi Zero W'nin dahili ses kalitesi çok düşüktür."
    echo "5-10 dolarlık USB ses kartı büyük fark yaratır."
    echo ""
fi

# PulseAudio problemi
if ! systemctl is-active --quiet pulseaudio-mp3player.service; then
    echo -e "${YELLOW}Öneri 2:${NC} PulseAudio'yu başlatın"
    echo "sudo systemctl start pulseaudio-mp3player.service"
    echo "sudo systemctl enable pulseaudio-mp3player.service"
    echo ""
fi

# Pygame problemi
if ! sudo -u mp3player /opt/mp3player/venv/bin/python -c "import pygame; pygame.mixer.init()" 2>/dev/null; then
    echo -e "${YELLOW}Öneri 3:${NC} Pygame'i yeniden kurun"
    echo "sudo -u mp3player /opt/mp3player/venv/bin/pip uninstall pygame"
    echo "sudo -u mp3player /opt/mp3player/venv/bin/pip install pygame"
    echo ""
fi

# Alternatif ses sistemi
echo -e "${YELLOW}Öneri 4:${NC} Alternatif ses kütüphanesi deneyin"
echo "Pygame yerine mpg123 veya omxplayer kullanabilirsiniz:"
echo "sudo apt install mpg123"

echo -e "\n${BLUE}[10] Hızlı Çözüm Denemeleri${NC}"
echo "=================================="

read -p "PulseAudio'yu yeniden başlatmak ister misiniz? (y/n): " restart_pulse
if [[ $restart_pulse =~ ^[Yy]$ ]]; then
    echo "PulseAudio yeniden başlatılıyor..."
    systemctl stop mp3player.service
    systemctl stop pulseaudio-mp3player.service
    sleep 2
    systemctl start pulseaudio-mp3player.service
    sleep 3
    systemctl start mp3player.service
    echo "Servisler yeniden başlatıldı."
fi

read -p "Pygame mixer'ı sıfırlık ayarlarla test etmek ister misiniz? (y/n): " test_mixer
if [[ $test_mixer =~ ^[Yy]$ ]]; then
    echo "Pygame mixer test ediliyor..."
    sudo -u mp3player /opt/mp3player/venv/bin/python << 'EOF'
import pygame
import time

configs = [
    {'frequency': 22050, 'size': -16, 'channels': 2, 'buffer': 4096},
    {'frequency': 44100, 'size': -16, 'channels': 2, 'buffer': 2048},
    {'frequency': 22050, 'size': -16, 'channels': 1, 'buffer': 8192},
    {'frequency': 11025, 'size': -16, 'channels': 2, 'buffer': 4096},
]

for i, config in enumerate(configs):
    try:
        pygame.mixer.quit()
        pygame.mixer.pre_init(**config)
        pygame.mixer.init()
        print(f"✓ Konfigürasyon {i+1} başarılı: {config}")
        pygame.mixer.quit()
        time.sleep(1)
    except Exception as e:
        print(f"✗ Konfigürasyon {i+1} başarısız: {config} - {e}")

print("Test tamamlandı.")
EOF
fi

echo ""
echo "================================="
echo -e "${GREEN}Audio debug tamamlandı!${NC}"
echo "================================="
echo ""
echo "📋 Sonuçları inceleyip önerilen çözümleri deneyin."
echo "🔧 Hâlâ problem varsa USB ses kartı kullanmayı düşünün."
echo "📞 Destek için log'ları paylaşın: journalctl -u mp3player.service"
