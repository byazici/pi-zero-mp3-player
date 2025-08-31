#!/usr/bin/env python3
"""
Raspberry Pi Zero W MP3 Player
Web tabanlı MP3 çalar uygulaması
"""

import os
import json
import logging
from datetime import datetime
from pathlib import Path

import pygame
from flask import Flask, render_template, request, jsonify, redirect, url_for, send_from_directory
from werkzeug.utils import secure_filename
from mutagen.mp3 import MP3
from mutagen.id3 import ID3NoHeaderError

# Uygulama konfigürasyonu
app = Flask(__name__)
app.config['SECRET_KEY'] = 'raspberry-pi-mp3-player-2024'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB maksimum dosya boyutu

# Upload klasörünü oluştur
Path(app.config['UPLOAD_FOLDER']).mkdir(exist_ok=True)

# Logging ayarları
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s: %(message)s',
    handlers=[
        logging.FileHandler('/var/log/mp3player/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Global değişkenler
current_song = None
is_playing = False
current_position = 0
playlist = []
current_index = 0
volume = 0.7
shuffle_mode = False
repeat_mode = False

# Pygame mixer'ı başlat
try:
    pygame.mixer.pre_init(frequency=44100, size=-16, channels=2, buffer=2048)
    pygame.mixer.init()
    pygame.mixer.music.set_volume(volume)
    logger.info("Pygame mixer başlatıldı")
except pygame.error as e:
    logger.error(f"Ses sistemi başlatılamadı: {e}")


def allowed_file(filename):
    """İzin verilen dosya türlerini kontrol et"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() == 'mp3'


def get_mp3_info(filepath):
    """MP3 dosyasından meta bilgileri al"""
    try:
        audio = MP3(filepath)
        duration = int(audio.info.length) if audio.info.length else 0
        
        # ID3 tag bilgilerini al
        title = str(audio.get('TIT2', [Path(filepath).stem]))[0] if audio.get('TIT2') else Path(filepath).stem
        artist = str(audio.get('TPE1', ['Bilinmiyor']))[0] if audio.get('TPE1') else 'Bilinmiyor'
        
        return {
            'title': title,
            'artist': artist,
            'duration': duration,
            'duration_str': f"{duration//60}:{duration%60:02d}"
        }
    except (ID3NoHeaderError, Exception) as e:
        logger.warning(f"MP3 bilgisi okunamadı {filepath}: {e}")
        return {
            'title': Path(filepath).stem,
            'artist': 'Bilinmiyor',
            'duration': 0,
            'duration_str': '0:00'
        }


def load_playlist():
    """Upload klasöründeki MP3 dosyalarını yükle"""
    global playlist
    playlist = []
    
    upload_path = Path(app.config['UPLOAD_FOLDER'])
    for file_path in upload_path.glob('*.mp3'):
        if file_path.is_file():
            info = get_mp3_info(str(file_path))
            playlist.append({
                'filename': file_path.name,
                'filepath': str(file_path),
                'title': info['title'],
                'artist': info['artist'],
                'duration': info['duration'],
                'duration_str': info['duration_str'],
                'size': file_path.stat().st_size
            })
    
    # Dosya adına göre sırala
    playlist.sort(key=lambda x: x['filename'].lower())
    logger.info(f"Playlist yüklendi: {len(playlist)} dosya")


@app.route('/')
def index():
    """Ana sayfa"""
    load_playlist()
    return render_template('index.html')


@app.route('/api/files')
def get_files():
    """Dosya listesini JSON olarak döndür"""
    load_playlist()
    return jsonify({
        'files': playlist,
        'current_song': current_song,
        'is_playing': is_playing,
        'current_index': current_index,
        'volume': volume,
        'shuffle': shuffle_mode,
        'repeat': repeat_mode
    })


@app.route('/upload', methods=['POST'])
def upload_file():
    """Dosya yükleme"""
    if 'file' not in request.files:
        return jsonify({'error': 'Dosya seçilmedi'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'Dosya seçilmedi'}), 400
    
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        # Aynı isimde dosya varsa numaralandır
        counter = 1
        original_name = filename
        while os.path.exists(filepath):
            name, ext = os.path.splitext(original_name)
            filename = f"{name}_{counter}{ext}"
            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            counter += 1
        
        try:
            file.save(filepath)
            logger.info(f"Dosya yüklendi: {filename}")
            
            # MP3 bilgilerini kontrol et
            info = get_mp3_info(filepath)
            
            return jsonify({
                'success': True,
                'filename': filename,
                'info': info
            })
        except Exception as e:
            logger.error(f"Dosya yükleme hatası: {e}")
            return jsonify({'error': 'Dosya yüklenemedi'}), 500
    
    return jsonify({'error': 'Geçersiz dosya türü. Sadece MP3 dosyaları kabul edilir.'}), 400


@app.route('/api/play/<int:index>')
def play_song(index):
    """Belirtilen indeksteki şarkıyı çal"""
    global current_song, is_playing, current_index
    
    if not playlist or index < 0 or index >= len(playlist):
        return jsonify({'error': 'Geçersiz şarkı indeksi'}), 400
    
    try:
        song = playlist[index]
        pygame.mixer.music.load(song['filepath'])
        pygame.mixer.music.play()
        
        current_song = song
        current_index = index
        is_playing = True
        
        logger.info(f"Çalınıyor: {song['title']}")
        
        return jsonify({
            'success': True,
            'current_song': current_song,
            'is_playing': is_playing,
            'current_index': current_index
        })
    except pygame.error as e:
        logger.error(f"Şarkı çalma hatası: {e}")
        return jsonify({'error': 'Şarkı çalınamadı'}), 500


@app.route('/api/pause')
def pause_music():
    """Müziği duraklat/devam ettir"""
    global is_playing
    
    try:
        if is_playing:
            pygame.mixer.music.pause()
            is_playing = False
            logger.info("Müzik duraklatıldı")
        else:
            pygame.mixer.music.unpause()
            is_playing = True
            logger.info("Müzik devam ettirildi")
        
        return jsonify({
            'success': True,
            'is_playing': is_playing
        })
    except pygame.error as e:
        logger.error(f"Pause/unpause hatası: {e}")
        return jsonify({'error': 'İşlem gerçekleştirilemedi'}), 500


@app.route('/api/stop')
def stop_music():
    """Müziği durdur"""
    global is_playing, current_song
    
    try:
        pygame.mixer.music.stop()
        is_playing = False
        logger.info("Müzik durduruldu")
        
        return jsonify({
            'success': True,
            'is_playing': is_playing
        })
    except pygame.error as e:
        logger.error(f"Stop hatası: {e}")
        return jsonify({'error': 'İşlem gerçekleştirilemedi'}), 500


@app.route('/api/next')
def next_song():
    """Sonraki şarkı"""
    global current_index
    
    if not playlist:
        return jsonify({'error': 'Playlist boş'}), 400
    
    if shuffle_mode:
        import random
        current_index = random.randint(0, len(playlist) - 1)
    else:
        current_index = (current_index + 1) % len(playlist)
    
    return play_song(current_index)


@app.route('/api/previous')
def previous_song():
    """Önceki şarkı"""
    global current_index
    
    if not playlist:
        return jsonify({'error': 'Playlist boş'}), 400
    
    if shuffle_mode:
        import random
        current_index = random.randint(0, len(playlist) - 1)
    else:
        current_index = (current_index - 1) % len(playlist)
    
    return play_song(current_index)


@app.route('/api/volume/<float:level>')
def set_volume(level):
    """Ses seviyesini ayarla (0.0 - 1.0)"""
    global volume
    
    level = max(0.0, min(1.0, level))  # 0-1 arasında sınırla
    
    try:
        pygame.mixer.music.set_volume(level)
        volume = level
        logger.info(f"Ses seviyesi ayarlandı: {level:.2f}")
        
        return jsonify({
            'success': True,
            'volume': volume
        })
    except pygame.error as e:
        logger.error(f"Volume hatası: {e}")
        return jsonify({'error': 'Ses seviyesi ayarlanamadı'}), 500


@app.route('/api/toggle_shuffle')
def toggle_shuffle():
    """Karıştırma modunu aç/kapat"""
    global shuffle_mode
    
    shuffle_mode = not shuffle_mode
    logger.info(f"Shuffle modu: {shuffle_mode}")
    
    return jsonify({
        'success': True,
        'shuffle': shuffle_mode
    })


@app.route('/api/toggle_repeat')
def toggle_repeat():
    """Tekrar modunu aç/kapat"""
    global repeat_mode
    
    repeat_mode = not repeat_mode
    logger.info(f"Repeat modu: {repeat_mode}")
    
    return jsonify({
        'success': True,
        'repeat': repeat_mode
    })


@app.route('/api/delete/<filename>')
def delete_file(filename):
    """Dosyayı sil"""
    filename = secure_filename(filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    if not os.path.exists(filepath):
        return jsonify({'error': 'Dosya bulunamadı'}), 404
    
    try:
        # Şu an çalan şarkıysa durdur
        if current_song and current_song['filename'] == filename:
            stop_music()
        
        os.remove(filepath)
        logger.info(f"Dosya silindi: {filename}")
        
        return jsonify({'success': True})
    except Exception as e:
        logger.error(f"Dosya silme hatası: {e}")
        return jsonify({'error': 'Dosya silinemedi'}), 500


@app.route('/api/status')
def get_status():
    """Çalar durumunu döndür"""
    # Pygame'in müzik durumunu kontrol et
    if pygame.mixer.music.get_busy():
        # Müzik çalıyor ama bizim değişkenimiz False ise düzelt
        if not is_playing:
            globals()['is_playing'] = True
    else:
        # Müzik bitmiş, sonraki şarkıya geç (repeat mode kontrolü ile)
        if is_playing:
            if repeat_mode and current_song:
                # Aynı şarkıyı tekrar çal
                pygame.mixer.music.play()
            elif playlist:
                # Sonraki şarkıya geç
                next_song()
            else:
                globals()['is_playing'] = False
    
    return jsonify({
        'current_song': current_song,
        'is_playing': is_playing,
        'current_index': current_index,
        'volume': volume,
        'shuffle': shuffle_mode,
        'repeat': repeat_mode,
        'playlist_length': len(playlist)
    })


if __name__ == '__main__':
    logger.info("MP3 Player uygulaması başlatılıyor...")
    
    # İlk playlist'i yükle
    load_playlist()
    
    # Uygulamayı başlat
    app.run(
        host='0.0.0.0',
        port=5001,
        debug=False,
        threaded=True
    )