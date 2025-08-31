#!/bin/bash

# Raspberry Pi Zero W MP3 Player - Otomatik Kurulum Scripti
# Bu script'i root yetkisi ile çalıştırın: sudo bash install.sh

set -e

echo "🎵 Raspberry Pi Zero W MP3 Player Kurulumu Başlatılıyor..."
echo "==============================================="

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log fonksiyonu
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}[STEP]${NC} $1"
    echo "----------------------------------------"
}

# Root kontrolü
if [[ $EUID -ne 0 ]]; then
   log_error "Bu script root yetkileri ile çalıştırılmalıdır: sudo bash install.sh"
   exit 1
fi

# Raspberry Pi kontrolü
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    log_warning "Bu Raspberry Pi cihazı değil gibi görünüyor. Devam edilsin mi? (y/n)"
    read -p "Yanıt: " response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log_step "1. Sistem güncellemesi ve gerekli paketler"
apt update && apt upgrade -y
log_info "Sistem güncellendi"

# Temel sistem paketleri
apt install -y python3-pip python3-venv git curl wget
apt install -y alsa-utils pulseaudio pulseaudio-utils
apt install -y python3-dev libasound2-dev libportaudio2 libportaudiocpp0 portaudio19-dev
apt install -y supervisor nginx
log_info "Sistem paketleri yüklendi"

log_step "2. Kullanıcı ve dizin yapısı oluşturma"
# mp3player kullanıcısı varsa sil
if id "mp3player" &>/dev/null; then
    log_warning "mp3player kullanıcısı zaten mevcut, siliniyor..."
    systemctl stop mp3player.service 2>/dev/null || true
    userdel -r mp3player 2>/dev/null || true
fi

# Yeni kullanıcı oluştur
useradd -m -s /bin/bash mp3player
usermod -a -G audio mp3player
log_info "mp3player kullanıcısı oluşturuldu"

# Proje dizini
if [ -d "/opt/mp3player" ]; then
    log_warning "Proje dizini mevcut, yedekleniyor..."
    mv /opt/mp3player "/opt/mp3player.backup.$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p /opt/mp3player
chown mp3player:mp3player /opt/mp3player
log_info "Proje dizini oluşturuldu: /opt/mp3player"

log_step "3. Proje dosyalarını kopyalama"
cd /opt/mp3player

# Dizin yapısını oluştur
sudo -u mp3player mkdir -p uploads static/css static/js templates

# Dosyaları kopyala (script ile aynı dizindeyse)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/app.py" ]; then
    cp "$SCRIPT_DIR"/*.py /opt/mp3player/ 2>/dev/null || true
    cp "$SCRIPT_DIR/requirements.txt" /opt/mp3player/ 2>/dev/null || true
    cp -r "$SCRIPT_DIR/templates"/* /opt/mp3player/templates/ 2>/dev/null || true
    cp -r "$SCRIPT_DIR/static"/* /opt/mp3player/static/ 2>/dev/null || true
    log_info "Proje dosyaları kopyalandı"
else
    log_warning "Proje dosyaları bulunamadı. Manuel olarak kopyalamanız gerekiyor:"
    echo "  - app.py -> /opt/mp3player/"
    echo "  - requirements.txt -> /opt/mp3player/"
    echo "  - templates/ -> /opt/mp3player/templates/"
    echo "  - static/ -> /opt/mp3player/static/"
fi

chown -R mp3player:mp3player /opt/mp3player
chmod 755 /opt/mp3player
chmod 777 /opt/mp3player/uploads
log_info "Dosya izinleri ayarlandı"

log_step "4. Python sanal ortamı ve bağımlılıklar"
sudo -u mp3player python3 -m venv /opt/mp3player/venv
sudo -u mp3player /opt/mp3player/venv/bin/pip install --upgrade pip

# requirements.txt yoksa oluştur
if [ ! -f "/opt/mp3player/requirements.txt" ]; then
    cat > /opt/mp3player/requirements.txt << EOF
Flask==2.3.3
pygame==2.5.2
mutagen==1.47.0
gunicorn==21.2.0
werkzeug==2.3.7
EOF
fi

sudo -u mp3player /opt/mp3player/venv/bin/pip install -r /opt/mp3player/requirements.txt
log_info "Python bağımlılıkları yüklendi"

log_step "5. Ses sistemi konfigürasyonu"
# ALSA konfigürasyonu
sudo -u mp3player cat > /home/mp3player/.asoundrc << 'EOF'
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOF

# PulseAudio için systemd servisi
cat > /etc/systemd/system/pulseaudio-mp3player.service << 'EOF'
[Unit]
Description=PulseAudio for MP3Player
After=sound.target

[Service]
Type=forking
User=mp3player
Group=mp3player
ExecStart=/usr/bin/pulseaudio --start --log-target=syslog
ExecStop=/usr/bin/pulseaudio --kill
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pulseaudio-mp3player.service
systemctl start pulseaudio-mp3player.service
log_info "Ses sistemi konfigüre edildi"

log_step "6. Systemd servisi oluşturma"
cat > /etc/systemd/system/mp3player.service << 'EOF'
[Unit]
Description=MP3 Player Web Application
After=network.target sound.target pulseaudio-mp3player.service

[Service]
Type=simple
User=mp3player
Group=mp3player
WorkingDirectory=/opt/mp3player
Environment=PATH=/opt/mp3player/venv/bin
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production
ExecStart=/opt/mp3player/venv/bin/python app.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

# Ses sistem erişimi için
SupplementaryGroups=audio

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mp3player.service
log_info "MP3Player servisi oluşturuldu"

log_step "7. Nginx reverse proxy konfigürasyonu"
# Nginx default site'ı devre dışı bırak
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
fi

# MP3Player site konfigürasyonu
cat > /etc/nginx/sites-available/mp3player << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    client_body_timeout 300s;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
    # Static dosyalar için
    location /static {
        alias /opt/mp3player/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    # Upload progress için
    location /upload {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_request_buffering off;
    }
}
EOF

ln -s /etc/nginx/sites-available/mp3player /etc/nginx/sites-enabled/
nginx -t
systemctl enable nginx
systemctl reload nginx
log_info "Nginx konfigüre edildi"

log_step "8. Log dizini ve izinler"
mkdir -p /var/log/mp3player
chown mp3player:mp3player /var/log/mp3player
log_info "Log dizini oluşturuldu"

log_step "9. Boot konfigürasyonu"
# rc.local güncellemesi (PulseAudio backup için)
if ! grep -q "pulseaudio-mp3player" /etc/rc.local; then
    # rc.local yoksa oluştur
    if [ ! -f "/etc/rc.local" ]; then
        cat > /etc/rc.local << 'EOF'
#!/bin/sh -e
exit 0
EOF
        chmod +x /etc/rc.local
    fi
    
    # PulseAudio backup başlatma komutunu ekle
    sed -i '/exit 0/i # MP3Player PulseAudio backup\nif ! systemctl is-active --quiet pulseaudio-mp3player.service; then\n    systemctl start pulseaudio-mp3player.service\nfi\n' /etc/rc.local
fi

log_info "Boot konfigürasyonu tamamlandı"

log_step "10. Güvenlik ve firewall (opsiyonel)"
read -p "UFW firewall kurulsun mu? (y/n): " setup_firewall
if [[ $setup_firewall =~ ^[Yy]$ ]]; then
    apt install -y ufw
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw --force enable
    log_info "UFW firewall konfigüre edildi"
else
    log_info "Firewall kurulumu atlandı"
fi

log_step "11. Servisleri başlatma"
systemctl start mp3player.service
sleep 3

# Servis durumunu kontrol et
if systemctl is-active --quiet mp3player.service; then
    log_info "MP3Player servisi başlatıldı ✓"
else
    log_error "MP3Player servisi başlatılamadı ✗"
    echo "Hata detayları:"
    systemctl status mp3player.service --no-pager -l
fi

if systemctl is-active --quiet nginx; then
    log_info "Nginx servisi çalışıyor ✓"
else
    log_error "Nginx servisi çalışmıyor ✗"
fi

log_step "12. Test ve doğrulama"
# IP adresini bul
PI_IP=$(hostname -I | awk '{print $1}')

echo
echo "==============================================="
echo -e "${GREEN}🎵 KURULUM TAMAMLANDI! 🎵${NC}"
echo "==============================================="
echo
echo "📍 Raspberry Pi IP Adresi: $PI_IP"
echo "🌐 Web Arayüzü: http://$PI_IP"
echo "🔧 Servis durumu: systemctl status mp3player.service"
echo "📋 Loglar: journalctl -u mp3player.service -f"
echo
echo "📁 Proje dizini: /opt/mp3player"
echo "👤 Kullanıcı: mp3player"
echo "📂 Upload klasörü: /opt/mp3player/uploads"
echo

echo "🔍 SON KONTROLLER:"
echo "=================="

# Ses kartı kontrolü
if aplay -l | grep -q "card"; then
    log_info "Ses kartı algılandı ✓"
else
    log_warning "Ses kartı bulunamadı! USB ses kartı takmanız gerekebilir"
fi

# Disk alanı kontrolü
AVAILABLE_SPACE=$(df /opt/mp3player | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
if [ $AVAILABLE_GB -gt 1 ]; then
    log_info "Yeterli disk alanı: ${AVAILABLE_GB}GB ✓"
else
    log_warning "Düşük disk alanı: ${AVAILABLE_GB}GB"
fi

# Port kontrolü
if netstat -tlnp | grep -q ":5000"; then
    log_info "Flask uygulaması port 5000'de çalışıyor ✓"
else
    log_warning "Flask uygulaması port 5000'de çalışmıyor"
fi

if netstat -tlnp | grep -q ":80"; then
    log_info "Nginx port 80'de çalışıyor ✓"
else
    log_warning "Nginx port 80'de çalışmıyor"
fi

echo
echo -e "${GREEN}Kurulum tamamlandı! Web tarayıcınızda http://$PI_IP adresine gidin.${NC}"
echo -e "${YELLOW}İlk kullanımda ses kartının tanınması birkaç dakika sürebilir.${NC}"
echo
echo "🚀 MP3 dosyalarınızı yükleyip müzik dinlemeye başlayabilirsiniz!"
echo

# Otomatik tarayıcı açma önerisi
read -p "Şimdi web arayüzünü tarayıcıda açmak ister misiniz? (y/n): " open_browser
if [[ $open_browser =~ ^[Yy]$ ]]; then
    if command -v chromium-browser &> /dev/null; then
        sudo -u pi DISPLAY=:0 chromium-browser "http://$PI_IP" &
    elif command -v firefox &> /dev/null; then
        sudo -u pi DISPLAY=:0 firefox "http://$PI_IP" &
    else
        echo "Tarayıcı bulunamadı. Manuel olarak http://$PI_IP adresini ziyaret edin."
    fi
fi