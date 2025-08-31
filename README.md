# 🎵 Raspberry Pi Zero W MP3 Player

Raspberry Pi Zero W için web tabanlı, hafif ve kullanıcı dostu MP3 çalar uygulaması.

## 🚀 Özellikler

### 🎶 Müzik Çalma
- **Web tabanlı arayüz** - Modern ve responsive tasarım
- **Drag & Drop upload** - MP3 dosyalarını kolayca yükleyin
- **Playlist yönetimi** - Şarkıları listeleyin, çalın ve silin
- **Player kontrolleri** - Çal/Durdur/Atla, ses seviyesi kontrolü
- **Shuffle/Repeat modları** - Karıştırma ve tekrar seçenekleri

### 📱 Kullanıcı Deneyimi
- **Responsive tasarım** - Telefon, tablet ve bilgisayarda çalışır
- **Real-time updates** - Çalar durumu otomatik güncellenir
- **Progress tracking** - Şarkı ilerlemesi ve süre gösterimi
- **File management** - Dosya boyutu, süre ve meta bilgiler

### ⚡ Performans
- **Hafif yapı** - Pi Zero W için optimize edilmiş
- **Düşük RAM kullanımı** - Streaming oynatma
- **Hızlı başlatma** - 30 saniye altında hazır
- **Güvenilir ses sistemi** - PulseAudio + pygame integration

## 📋 Sistem Gereksinimleri

### Donanım
- **Raspberry Pi Zero W** (veya daha güçlü Pi modeli)
- **MicroSD Kart** - En az 8GB (16GB önerilen)
- **Ses Çıkışı** - USB ses kartı veya HAT (dahili analog çıkış düşük kalitede)
- **Güç Kaynağı** - 5V 2.5A önerilen

### Yazılım
- **Raspberry Pi OS** (Lite veya Desktop)
- **Python 3.8+**
- **İnternet bağlantısı** (kurulum için)

## 🛠️ Kurulum

### Otomatik Kurulum (Önerilen)

1. **Kurulum scriptini indirin:**
```bash
wget https://raw.githubusercontent.com/[REPO]/main/install.sh
chmod +x install.sh
```

2. **Root yetkisi ile çalıştırın:**
```bash
sudo bash install.sh
```

3. **Kurulum tamamlandığında:**
   - Web arayüzü: `http://[PI_IP_ADRESI]`
   - Servis durumu: `systemctl status mp3player.service`

### Manuel Kurulum

Detaylı kurulum adımları için [SETUP.md](SETUP.md) dosyasına bakın.

## 🎯 Kullanım

### İlk Çalıştırma

1. **Web arayüzüne erişin:**
   ```
   http://[RASPBERRY_PI_IP_ADRESI]
   ```

2. **MP3 dosyalarını yükleyin:**
   - Drag & drop ile sürükleyin
   - Veya "Dosya Seç" butonunu kullanın

3. **Müzik dinlemeye başlayın:**
   - Playlist'ten şarkı seçin
   - Player kontrollerini kullanın

### Player Kontrolleri

| Kontrol | Açıklama |
|---------|----------|
| ▶️ | Çal/Durdur |
| ⏹️ | Tamamen durdur |
| ⏮️ | Önceki şarkı |
| ⏭️ | Sonraki şarkı |
| 🔀 | Karıştırma modu |
| 🔁 | Tekrar modu |
| 🔊 | Ses seviyesi |

### Dosya Yönetimi

- **Desteklenen format:** MP3
- **Maksimum dosya boyutu:** 100MB
- **Meta bilgiler:** Başlık, sanatçı, süre otomatik algılanır
- **Silme:** Her şarkının yanındaki çöp kutusu ikonu

## 🔧 Konfigürasyon

### Servis Yönetimi

```bash
# Servisi başlat
sudo systemctl start mp3player.service

# Servisi durdur
sudo systemctl stop mp3player.service

# Servisi yeniden başlat
sudo systemctl restart mp3player.service

# Servis durumu
sudo systemctl status mp3player.service

# Boot'ta otomatik başlatma
sudo systemctl enable mp3player.service
```

### Ses Sistemi

```bash
# Ses kartlarını listele
aplay -l

# Ses seviyesini ayarla
alsamixer

# PulseAudio durumu
pulseaudio --check -v

# Ses test
speaker-test -c 2 -t wav
```

### Log Dosyaları

```bash
# Uygulama logları
sudo journalctl -u mp3player.service -f

# Nginx logları
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Sistem logları
sudo tail -f /var/log/mp3player/app.log
```

## 🎨 Özelleştirme

### Tema Değişikliği

CSS dosyasını düzenleyin:
```bash
sudo nano /opt/mp3player/static/css/style.css
```

### Port Değişikliği

```bash
# Flask uygulamasında
sudo nano /opt/mp3player/app.py
# Son satırda port=5000'i değiştirin

# Nginx konfigürasyonunda
sudo nano /etc/nginx/sites-available/mp3player
# proxy_pass http://127.0.0.1:YENI_PORT;
```

### Upload Limiti

```bash
# Flask uygulamasında
sudo nano /opt/mp3player/app.py
# MAX_CONTENT_LENGTH değerini değiştirin

# Nginx'te
sudo nano /etc/nginx/sites-available/mp3player
# client_max_body_size değerini değiştirin
```

## 🔍 Sorun Giderme

### Yaygın Problemler

#### 🔇 Ses Çıkmıyor
```bash
# Ses kartı kontrolü
aplay -l

# ALSA ayarları
alsamixer

# PulseAudio yeniden başlat
sudo systemctl restart pulseaudio-mp3player.service
```

#### 🌐 Web arayüzüne erişilemiyor
```bash
# Servis durumu
sudo systemctl status mp3player.service

# Port kontrolü
netstat -tlnp | grep :80
netstat -tlnp | grep :5000

# Firewall kontrolü
sudo ufw status
```

#### 📁 Dosya yüklenmiyor
```bash
# Upload klasörü izinleri
ls -la /opt/mp3player/uploads/
sudo chmod 777 /opt/mp3player/uploads/

# Disk alanı kontrolü
df -h /opt/mp3player
```

#### 🔄 Servis başlamıyor
```bash
# Detaylı log
sudo journalctl -u mp3player.service --no-pager -l

# Manuel başlatma test
cd /opt/mp3player
source venv/bin/activate
python app.py
```

### Performans İyileştirme

#### Pi Zero W için optimizasyon
```bash
# GPU memory split (ses için gereksiz)
echo "gpu_mem=16" | sudo tee -a /boot/config.txt

# CPU governor
echo "performance" | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Swap dosyası boyutu
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=1024
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

## 📊 Sistem İzleme

### Kaynak Kullanımı

```bash
# CPU ve RAM kullanımı
htop

# Disk kullanımı
df -h

# Ağ trafiği
iftop

# Ses sistem durumu
pactl info
```

### Güvenlik

```bash
# UFW firewall
sudo ufw status verbose

# SSH güvenliği
sudo nano /etc/ssh/sshd_config
# PasswordAuthentication no
# PermitRootLogin no

# Otomatik güncellemeler
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

## 🔄 Güncelleme

### Uygulama Güncellemesi

```bash
# Servisi durdur
sudo systemctl stop mp3player.service

# Yeni kodu al
cd /opt/mp3player
sudo -u mp3player git pull  # veya dosyaları manuel kopyala

# Bağımlılıkları güncelle
sudo -u mp3player /opt/mp3player/venv/bin/pip install -r requirements.txt

# Servisi başlat
sudo systemctl start mp3player.service
```

### Sistem Güncellemesi

```bash
# Paket güncellemeleri
sudo apt update && sudo apt upgrade -y

# Python paketleri
sudo -u mp3player /opt/mp3player/venv/bin/pip install --upgrade pip
sudo -u mp3player /opt/mp3player/venv/bin/pip list --outdated
```

## 📦 Yedekleme

### Konfigürasyon Yedekleme

```bash
sudo tar -czf mp3player-backup-$(date +%Y%m%d).tar.gz \
    /opt/mp3player/ \
    /etc/systemd/system/mp3player.service \
    /etc/systemd/system/pulseaudio-mp3player.service \
    /etc/nginx/sites-available/mp3player
```

### Müzik Koleksiyonu Yedekleme

```bash
sudo tar -czf music-backup-$(date +%Y%m%d).tar.gz \
    /opt/mp3player/uploads/
```

## 🤝 Katkıda Bulunma

1. Repository'yi fork edin
2. Feature branch oluşturun (`git checkout -b feature/YeniOzellik`)
3. Değişikliklerinizi commit edin (`git commit -am 'Yeni özellik ekle'`)
4. Branch'i push edin (`git push origin feature/YeniOzellik`)
5. Pull Request oluşturun

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır - detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 🙏 Teşekkürler

- [Flask](https://flask.palletsprojects.com/) - Web framework
- [pygame](https://www.pygame.org/) - Audio playback
- [Bootstrap](https://getbootstrap.com/) - UI components
- [Font Awesome](https://fontawesome.com/) - Icons

## 📞 Destek

- **Sorunlar:** GitHub Issues
- **Özellik istekleri:** GitHub Discussions
- **Dokümantasyon:** Wiki sayfaları

---

🎵 **Müzik dinlemenin keyfini çıkarın!** 🎵