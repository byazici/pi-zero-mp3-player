# Raspberry Pi Zero W MP3 Player - Kurulum Rehberi

## 1. Sistem Hazırlığı

### Raspberry Pi OS Kurulumu
```bash
# Sistem güncellemesi
sudo apt update && sudo apt upgrade -y

# Gerekli sistem paketleri
sudo apt install -y python3-pip python3-venv git nginx supervisor
sudo apt install -y alsa-utils pulseaudio pulseaudio-utils
sudo apt install -y python3-dev libasound2-dev libportaudio2 libportaudiocpp0 portaudio19-dev

# Ses sistemi kontrol
sudo usermod -a -G audio pi
```

### Kullanıcı ve Dizin Yapısı
```bash
# Proje kullanıcısı oluştur
sudo useradd -m -s /bin/bash mp3player
sudo usermod -a -G audio mp3player

# Proje dizini oluştur
sudo mkdir -p /opt/mp3player
sudo chown mp3player:mp3player /opt/mp3player

# Kullanıcıya geç
sudo su - mp3player
```

## 2. Proje Kurulumu

### Kaynak kodları
```bash
cd /opt/mp3player
git clone <repo_url> .  # Veya dosyaları manuel kopyala

# Dizin yapısını oluştur
mkdir -p uploads static/css static/js templates
```

### Python Sanal Ortamı
```bash
# Sanal ortam oluştur
python3 -m venv venv
source venv/bin/activate

# Gereksinimleri yükle
pip install -r requirements.txt
```

## 3. Ses Sistemi Konfigürasyonu

### ALSA Ayarları
```bash
# /home/mp3player/.asoundrc dosyası oluştur
cat > ~/.asoundrc << 'EOF'
pcm.!default {
    type pulse
}
ctl.!default {
    type pulse
}
EOF

# Ses kartını test et
aplay /usr/share/sounds/alsa/Front_Left.wav
```

### PulseAudio Başlatma
```bash
# PulseAudio servisini başlat
pulseaudio --start --log-target=syslog

# Ses seviyesini ayarla
pactl set-sink-volume @DEFAULT_SINK@ 50%
```

## 4. Systemd Servisi

### /etc/systemd/system/mp3player.service
```ini
[Unit]
Description=MP3 Player Web Application
After=network.target sound.target

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

# Ses sistem erişimi için
SupplementaryGroups=audio

[Install]
WantedBy=multi-user.target
```

### Servisi Aktifleştir
```bash
# Systemd servisini yükle
sudo systemctl daemon-reload
sudo systemctl enable mp3player.service
sudo systemctl start mp3player.service

# Durumu kontrol et
sudo systemctl status mp3player.service
```

## 5. Nginx Reverse Proxy (Opsiyonel)

### /etc/nginx/sites-available/mp3player
```nginx
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static dosyalar için
    location /static {
        alias /opt/mp3player/static;
        expires 30d;
    }
}
```

```bash
# Nginx konfigürasyonu
sudo ln -s /etc/nginx/sites-available/mp3player /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
```

## 6. Güvenlik ve İzinler

### Dosya İzinleri
```bash
# Proje dosyaları
sudo chown -R mp3player:mp3player /opt/mp3player
chmod 755 /opt/mp3player
chmod 777 /opt/mp3player/uploads  # Upload dizini yazılabilir olmalı

# Log dizini
sudo mkdir -p /var/log/mp3player
sudo chown mp3player:mp3player /var/log/mp3player
```

### UFW Firewall (Opsiyonel)
```bash
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw enable
```

## 7. Boot Otomasyonu

### /etc/rc.local (PulseAudio için)
```bash
# /etc/rc.local dosyasına ekle (exit 0'dan önce)
# PulseAudio'yu mp3player kullanıcısı için başlat
sudo -u mp3player pulseaudio --start --log-target=syslog &
```

## 8. Test ve Doğrulama

### Servis Durumu
```bash
# Tüm servisleri kontrol et
sudo systemctl status mp3player.service
sudo systemctl status nginx.service

# Log dosyalarını kontrol et
sudo journalctl -u mp3player.service -f
tail -f /var/log/mp3player/app.log
```

### Web Arayüzü Test
```bash
# Pi'nin IP adresini öğren
ip addr show wlan0

# Tarayıcıda test et: http://PI_IP_ADDRESS
curl http://localhost/
```

## 9. Sorun Giderme

### Ses Problemi
```bash
# Ses kartlarını listele
aplay -l

# PulseAudio durumu
pulseaudio --check -v

# Ses test
speaker-test -c 2 -t wav
```

### Dosya İzin Problemi
```bash
# Upload dizini izinleri
ls -la /opt/mp3player/uploads/
sudo chmod 777 /opt/mp3player/uploads/
```

### Servis Durumu
```bash
# Detaylı log
sudo journalctl -u mp3player.service --no-pager -l

# Manuel başlatma test
cd /opt/mp3player
source venv/bin/activate
python app.py
```

## 10. Yedekleme ve Güncelleme

### Konfigürasyon Yedekleme
```bash
# Önemli konfigürasyon dosyaları
sudo tar -czf mp3player-backup.tar.gz \
    /opt/mp3player/ \
    /etc/systemd/system/mp3player.service \
    /etc/nginx/sites-available/mp3player
```

### Güncelleme
```bash
# Servisi durdur
sudo systemctl stop mp3player.service

# Kodu güncelle
cd /opt/mp3player
git pull  # veya yeni dosyaları kopyala

# Servisi başlat
sudo systemctl start mp3player.service
```

## Notlar
- Pi Zero W'nin sınırlı RAM'i (512MB) olduğunu unutma
- Büyük MP3 dosyaları için disk alanını kontrol et
- WiFi bağlantı kalitesi upload hızını etkiler
- İlk açılışta ses kartı tanıma biraz zaman alabilir