/**
 * Pi MP3 Player - JavaScript Controller
 */

class MP3Player {
    constructor() {
        this.currentSong = null;
        this.isPlaying = false;
        this.playlist = [];
        this.currentIndex = -1;
        this.volume = 0.7;
        this.shuffle = false;
        this.repeat = false;
        this.progressUpdateInterval = null;
        
        this.initializeElements();
        this.bindEvents();
        this.loadPlaylist();
        this.startStatusUpdates();
    }

    initializeElements() {
        // Upload elements
        this.dropZone = document.getElementById('drop-zone');
        this.fileInput = document.getElementById('file-input');
        this.uploadProgress = document.getElementById('upload-progress');
        
        // Player elements
        this.currentSongTitle = document.getElementById('current-song-title');
        this.currentSongArtist = document.getElementById('current-song-artist');
        this.playPauseBtn = document.getElementById('play-pause-btn');
        this.stopBtn = document.getElementById('stop-btn');
        this.prevBtn = document.getElementById('prev-btn');
        this.nextBtn = document.getElementById('next-btn');
        this.progressBar = document.getElementById('progress-bar');
        this.currentTime = document.getElementById('current-time');
        this.totalTime = document.getElementById('total-time');
        this.volumeSlider = document.getElementById('volume-slider');
        this.volumeDisplay = document.getElementById('volume-display');
        this.shuffleBtn = document.getElementById('shuffle-btn');
        this.repeatBtn = document.getElementById('repeat-btn');
        
        // Playlist elements
        this.playlist = document.getElementById('playlist');
        this.playlistCount = document.getElementById('playlist-count');
        this.alertContainer = document.getElementById('alert-container');
    }

    bindEvents() {
        // Upload events
        this.dropZone.addEventListener('click', () => this.fileInput.click());
        this.dropZone.addEventListener('dragover', this.handleDragOver.bind(this));
        this.dropZone.addEventListener('dragleave', this.handleDragLeave.bind(this));
        this.dropZone.addEventListener('drop', this.handleDrop.bind(this));
        this.fileInput.addEventListener('change', this.handleFileSelect.bind(this));

        // Player control events
        this.playPauseBtn.addEventListener('click', this.togglePlayPause.bind(this));
        this.stopBtn.addEventListener('click', this.stopMusic.bind(this));
        this.prevBtn.addEventListener('click', this.previousSong.bind(this));
        this.nextBtn.addEventListener('click', this.nextSong.bind(this));
        this.volumeSlider.addEventListener('input', this.updateVolume.bind(this));
        this.shuffleBtn.addEventListener('click', this.toggleShuffle.bind(this));
        this.repeatBtn.addEventListener('click', this.toggleRepeat.bind(this));
    }

    // File Upload Handlers
    handleDragOver(e) {
        e.preventDefault();
        this.dropZone.classList.add('dragover');
    }

    handleDragLeave(e) {
        e.preventDefault();
        this.dropZone.classList.remove('dragover');
    }

    handleDrop(e) {
        e.preventDefault();
        this.dropZone.classList.remove('dragover');
        const files = Array.from(e.dataTransfer.files).filter(file => 
            file.type === 'audio/mpeg' || file.name.toLowerCase().endsWith('.mp3')
        );
        if (files.length > 0) {
            this.uploadFiles(files);
        } else {
            this.showAlert('Lütfen sadece MP3 dosyaları yükleyin.', 'warning');
        }
    }

    handleFileSelect(e) {
        const files = Array.from(e.target.files);
        if (files.length > 0) {
            this.uploadFiles(files);
        }
    }

    async uploadFiles(files) {
        this.showUploadProgress(true);
        
        for (let i = 0; i < files.length; i++) {
            const file = files[i];
            const progress = ((i + 1) / files.length) * 100;
            
            try {
                await this.uploadSingleFile(file);
                this.updateUploadProgress(progress, `${i + 1}/${files.length} dosya yüklendi`);
            } catch (error) {
                this.showAlert(`${file.name} yüklenemedi: ${error.message}`, 'danger');
            }
        }
        
        this.showUploadProgress(false);
        this.loadPlaylist();
        this.fileInput.value = '';
    }

    uploadSingleFile(file) {
        return new Promise((resolve, reject) => {
            const formData = new FormData();
            formData.append('file', file);

            fetch('/upload', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    resolve(data);
                } else {
                    reject(new Error(data.error));
                }
            })
            .catch(error => reject(error));
        });
    }

    showUploadProgress(show) {
        this.uploadProgress.classList.toggle('d-none', !show);
    }

    updateUploadProgress(percent, status) {
        const progressBar = this.uploadProgress.querySelector('.progress-bar');
        const statusText = document.getElementById('upload-status');
        
        progressBar.style.width = `${percent}%`;
        statusText.textContent = status;
    }

    // Playlist Management
    async loadPlaylist() {
        try {
            const response = await fetch('/api/files');
            const data = await response.json();
            
            this.playlist = data.files;
            this.currentSong = data.current_song;
            this.isPlaying = data.is_playing;
            this.currentIndex = data.current_index;
            this.volume = data.volume;
            this.shuffle = data.shuffle;
            this.repeat = data.repeat;
            
            this.updatePlaylistDisplay();
            this.updatePlayerDisplay();
            this.updateControlStates();
            
        } catch (error) {
            console.error('Playlist yüklenemedi:', error);
            this.showAlert('Playlist yüklenemedi', 'danger');
        }
    }

    updatePlaylistDisplay() {
        this.playlistCount.textContent = `${this.playlist.length} şarkı`;
        
        if (this.playlist.length === 0) {
            this.playlist.innerHTML = `
                <div class="list-group-item bg-secondary text-center text-muted py-4">
                    <i class="fas fa-music fa-2x mb-2"></i>
                    <p class="mb-0">Henüz şarkı yüklenmemiş</p>
                </div>
            `;
            return;
        }

        this.playlist.innerHTML = this.playlist.map((song, index) => `
            <div class="list-group-item playlist-item bg-secondary text-light d-flex align-items-center p-3 ${index === this.currentIndex ? 'active playing' : ''}" 
                 data-index="${index}">
                <div class="song-info me-3">
                    <div class="song-title">${this.escapeHtml(song.title)}</div>
                    <div class="song-meta">
                        <span>${this.escapeHtml(song.artist)}</span> • 
                        <span>${song.duration_str}</span> • 
                        <span>${this.formatFileSize(song.size)}</span>
                    </div>
                </div>
                <div class="song-controls">
                    <button class="btn btn-outline-light btn-sm" onclick="player.playSong(${index})" title="Çal">
                        <i class="fas fa-play"></i>
                    </button>
                    <button class="btn btn-outline-danger btn-sm" onclick="player.deleteSong('${song.filename}')" title="Sil">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </div>
        `).join('');
    }

    updatePlayerDisplay() {
        if (this.currentSong) {
            this.currentSongTitle.textContent = this.currentSong.title;
            this.currentSongArtist.textContent = this.currentSong.artist;
            this.totalTime.textContent = this.currentSong.duration_str;
        } else {
            this.currentSongTitle.textContent = 'Şarkı seçin';
            this.currentSongArtist.textContent = '-';
            this.totalTime.textContent = '0:00';
        }

        // Volume display
        this.volumeSlider.value = this.volume * 100;
        this.volumeDisplay.textContent = `${Math.round(this.volume * 100)}%`;

        // Play/Pause button
        const icon = this.playPauseBtn.querySelector('i');
        if (this.isPlaying) {
            icon.className = 'fas fa-pause';
        } else {
            icon.className = 'fas fa-play';
        }
    }

    updateControlStates() {
        const hasPlaylist = this.playlist.length > 0;
        
        this.playPauseBtn.disabled = !hasPlaylist;
        this.stopBtn.disabled = !hasPlaylist;
        this.prevBtn.disabled = !hasPlaylist;
        this.nextBtn.disabled = !hasPlaylist;

        // Shuffle and repeat button states
        this.shuffleBtn.classList.toggle('btn-active', this.shuffle);
        this.repeatBtn.classList.toggle('btn-active', this.repeat);
    }

    // Player Controls
    async togglePlayPause() {
        if (!this.currentSong && this.playlist.length > 0) {
            // İlk şarkıyı başlat
            await this.playSong(0);
            return;
        }

        try {
            const response = await fetch('/api/pause');
            const data = await response.json();
            
            if (data.success) {
                this.isPlaying = data.is_playing;
                this.updatePlayerDisplay();
            }
        } catch (error) {
            this.showAlert('İşlem gerçekleştirilemedi', 'danger');
        }
    }

    async stopMusic() {
        try {
            const response = await fetch('/api/stop');
            const data = await response.json();
            
            if (data.success) {
                this.isPlaying = false;
                this.updatePlayerDisplay();
                this.progressBar.style.width = '0%';
                this.currentTime.textContent = '0:00';
            }
        } catch (error) {
            this.showAlert('İşlem gerçekleştirilemedi', 'danger');
        }
    }

    async playSong(index) {
        try {
            const response = await fetch(`/api/play/${index}`);
            const data = await response.json();
            
            if (data.success) {
                this.currentSong = data.current_song;
                this.isPlaying = data.is_playing;
                this.currentIndex = data.current_index;
                
                this.updatePlayerDisplay();
                this.updatePlaylistDisplay();
                this.showAlert(`Çalınıyor: ${this.currentSong.title}`, 'success', 2000);
            }
        } catch (error) {
            this.showAlert('Şarkı çalınamadı', 'danger');
        }
    }

    async previousSong() {
        try {
            const response = await fetch('/api/previous');
            const data = await response.json();
            
            if (data.success) {
                this.currentSong = data.current_song;
                this.isPlaying = data.is_playing;
                this.currentIndex = data.current_index;
                
                this.updatePlayerDisplay();
                this.updatePlaylistDisplay();
            }
        } catch (error) {
            this.showAlert('Önceki şarkıya geçilemedi', 'danger');
        }
    }

    async nextSong() {
        try {
            const response = await fetch('/api/next');
            const data = await response.json();
            
            if (data.success) {
                this.currentSong = data.current_song;
                this.isPlaying = data.is_playing;
                this.currentIndex = data.current_index;
                
                this.updatePlayerDisplay();
                this.updatePlaylistDisplay();
            }
        } catch (error) {
            this.showAlert('Sonraki şarkıya geçilemedi', 'danger');
        }
    }

    async updateVolume() {
        const volume = this.volumeSlider.value / 100;
        
        try {
            const response = await fetch(`/api/volume/${volume}`);
            const data = await response.json();
            
            if (data.success) {
                this.volume = data.volume;
                this.volumeDisplay.textContent = `${Math.round(volume * 100)}%`;
            }
        } catch (error) {
            this.showAlert('Ses seviyesi ayarlanamadı', 'danger');
        }
    }

    async toggleShuffle() {
        try {
            const response = await fetch('/api/toggle_shuffle');
            const data = await response.json();
            
            if (data.success) {
                this.shuffle = data.shuffle;
                this.updateControlStates();
                this.showAlert(`Karıştırma ${this.shuffle ? 'açık' : 'kapalı'}`, 'info', 1500);
            }
        } catch (error) {
            this.showAlert('Karıştırma modu değiştirilemedi', 'danger');
        }
    }

    async toggleRepeat() {
        try {
            const response = await fetch('/api/toggle_repeat');
            const data = await response.json();
            
            if (data.success) {
                this.repeat = data.repeat;
                this.updateControlStates();
                this.showAlert(`Tekrar ${this.repeat ? 'açık' : 'kapalı'}`, 'info', 1500);
            }
        } catch (error) {
            this.showAlert('Tekrar modu değiştirilemedi', 'danger');
        }
    }

    async deleteSong(filename) {
        if (!confirm(`"${filename}" dosyasını silmek istediğinizden emin misiniz?`)) {
            return;
        }

        try {
            const response = await fetch(`/api/delete/${filename}`);
            const data = await response.json();
            
            if (data.success) {
                this.showAlert('Dosya silindi', 'success', 2000);
                await this.loadPlaylist();
            } else {
                this.showAlert(data.error || 'Dosya silinemedi', 'danger');
            }
        } catch (error) {
            this.showAlert('Dosya silme işlemi başarısız', 'danger');
        }
    }

    // Status Updates
    startStatusUpdates() {
        setInterval(async () => {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                // Durum değişikliği varsa güncelle
                if (data.is_playing !== this.isPlaying || 
                    data.current_index !== this.currentIndex) {
                    
                    this.currentSong = data.current_song;
                    this.isPlaying = data.is_playing;
                    this.currentIndex = data.current_index;
                    this.volume = data.volume;
                    this.shuffle = data.shuffle;
                    this.repeat = data.repeat;
                    
                    this.updatePlayerDisplay();
                    this.updatePlaylistDisplay();
                    this.updateControlStates();
                }
            } catch (error) {
                console.error('Status güncellemesi başarısız:', error);
            }
        }, 2000); // 2 saniyede bir kontrol et
    }

    // Utility Functions
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }

    showAlert(message, type = 'info', duration = 4000) {
        const alertId = Date.now();
        const alertHtml = `
            <div id="alert-${alertId}" class="alert alert-${type} alert-dismissible fade show" role="alert">
                ${message}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        `;
        
        this.alertContainer.insertAdjacentHTML('beforeend', alertHtml);
        
        // Otomatik kapat
        setTimeout(() => {
            const alertElement = document.getElementById(`alert-${alertId}`);
            if (alertElement) {
                const alert = new bootstrap.Alert(alertElement);
                alert.close();
            }
        }, duration);
    }
}

// Player instance'ını başlat
let player;
document.addEventListener('DOMContentLoaded', () => {
    player = new MP3Player();
});