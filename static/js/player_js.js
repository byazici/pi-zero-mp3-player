/**
 * Raspberry Pi MP3 Player - Frontend JavaScript
 */

class MP3Player {
    constructor() {
        this.currentSong = null;
        this.isPlaying = false;
        this.currentIndex = -1;
        this.playlist = [];
        this.volume = 70;
        this.shuffleMode = false;
        this.repeatMode = false;
        this.statusUpdateInterval = null;
        
        this.init();
    }
    
    init() {
        this.setupElements();
        this.setupEventListeners();
        this.loadPlaylist();
        this.startStatusUpdates();
    }
    
    setupElements() {
        // Player elements
        this.playPauseBtn = document.getElementById('play-pause-btn');
        this.stopBtn = document.getElementById('stop-btn');
        this.prevBtn = document.getElementById('prev-btn');
        this.nextBtn = document.getElementById('next-btn');
        this.volumeSlider = document.getElementById('volume-slider');
        this.volumeDisplay = document.getElementById('volume-display');
        this.shuffleBtn = document.getElementById('shuffle-btn');
        this.repeatBtn = document.getElementById('repeat-btn');
        this.progressBar = document.getElementById('progress-bar');
        this.currentTime = document.getElementById('current-time');
        this.totalTime = document.getElementById('total-time');
        this.currentSongTitle = document.getElementById('current-song-title');
        this.currentSongArtist = document.getElementById('current-song-artist');
        
        // Upload elements
        this.dropZone = document.getElementById('drop-zone');
        this.fileInput = document.getElementById('file-input');
        this.uploadProgress = document.getElementById('upload-progress');
        this.uploadStatus = document.getElementById('upload-status');
        
        // Playlist elements
        this.playlistElement = document.getElementById('playlist');
        this.playlistCount = document.getElementById('playlist-count');
        
        // Toast elements
        this.successToast = new bootstrap.Toast(document.getElementById('success-toast'));
        this.errorToast = new bootstrap.Toast(document.getElementById('error-toast'));
        this.successMessage = document.getElementById('success-message');
        this.errorMessage = document.getElementById('error-message');
    }
    
    setupEventListeners() {
        // Player controls
        this.playPauseBtn.addEventListener('click', () => this.togglePlayPause());
        this.stopBtn.addEventListener('click', () => this.stopMusic());
        this.prevBtn.addEventListener('click', () => this.previousSong());
        this.nextBtn.addEventListener('click', () => this.nextSong());
        
        // Volume control
        this.volumeSlider.addEventListener('input', (e) => this.setVolume(e.target.value));
        
        // Mode toggles
        this.shuffleBtn.addEventListener('click', () => this.toggleShuffle());
        this.repeatBtn.addEventListener('click', () => this.toggleRepeat());
        
        // Upload handling
        this.dropZone.addEventListener('click', () => this.fileInput.click());
        this.fileInput.addEventListener('change', (e) => this.handleFileSelect(e));
        
        // Drag and drop
        this.dropZone.addEventListener('dragover', (e) => this.handleDragOver(e));
        this.dropZone.addEventListener('dragleave', (e) => this.handleDragLeave(e));
        this.dropZone.addEventListener('drop', (e) => this.handleDrop(e));
    }
    
    async loadPlaylist() {
        try {
            const response = await fetch('/api/files');
            const data = await response.json();
            
            this.playlist = data.files || [];
            this.updatePlaylistUI();
            this.updatePlayerState(data);
            
        } catch (error) {
            console.error('Playlist yüklenirken hata:', error);
            this.showError('Playlist yüklenirken hata oluştu');
        }
    }
    
    updatePlaylistUI() {
        if (this.playlist.length === 0) {
            this.playlistElement.innerHTML = `
                <div class="list-group-item bg-secondary text-center text-muted py-4">
                    <i class="fas fa-music fa-2x mb-2"></i>
                    <p class="mb-0">Henüz şarkı yüklenmemiş</p>
                </div>
            `;
            this.playlistCount.textContent = '0 şarkı';
            return;
        }
        
        this.playlistElement.innerHTML = '';
        this.playlist.forEach((song, index) => {
            const isActive = this.currentIndex === index;
            const sizeInMB = (song.size / (1024 * 1024)).toFixed(1);
            
            const songElement = document.createElement('div');
            songElement.className = `list-group-item bg-secondary d-flex justify-content-between align-items-center song-item ${isActive ? 'active' : ''}`;
            songElement.innerHTML = `
                <div class="d-flex align-items-center flex-grow-1" style="cursor: pointer;">
                    <div class="me-3">
                        <i class="fas ${isActive && this.isPlaying ? 'fa-volume-up text-primary' : 'fa-music text-muted'}"></i>
                    </div>
                    <div class="flex-grow-1">
                        <div class="fw-semibold">${this.escapeHtml(song.title)}</div>
                        <small class="text-muted">${this.escapeHtml(song.artist)} • ${song.duration_str} • ${sizeInMB}MB</small>
                    </div>
                </div>
                <div class="btn-group">
                    <button class="btn btn-outline-danger btn-sm delete-btn" data-filename="${song.filename}">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            `;
            
            // Play song on click
            const playArea = songElement.querySelector('.d-flex.align-items-center');
            playArea.addEventListener('click', () => this.playSong(index));
            
            // Delete button
            const deleteBtn = songElement.querySelector('.delete-btn');
            deleteBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.deleteSong(song.filename);
            });
            
            this.playlistElement.appendChild(songElement);
        });
        
        this.playlistCount.textContent = `${this.playlist.length} şarkı`;
        this.updateControlsState();
    }
    
    updatePlayerState(data) {
        this.currentSong = data.current_song;
        this.isPlaying = data.is_playing || false;
        this.currentIndex = data.current_index || -1;
        this.volume = (data.volume || 0.7) * 100;
        this.shuffleMode = data.shuffle || false;
        this.repeatMode = data.repeat || false;
        
        this.updateUI();
    }
    
    updateUI() {
        // Song info
        if (this.currentSong) {
            this.currentSongTitle.textContent = this.currentSong.title;
            this.currentSongArtist.textContent = this.currentSong.artist;
            this.totalTime.textContent = this.currentSong.duration_str;
        } else {
            this.currentSongTitle.textContent = 'Şarkı seçin';
            this.currentSongArtist.textContent = '-';
            this.totalTime.textContent = '0:00';
        }
        
        // Play/pause button
        const icon = this.playPauseBtn.querySelector('i');
        if (this.isPlaying) {
            icon.className = 'fas fa-pause';
        } else {
            icon.className = 'fas fa-play';
        }
        
        // Volume
        this.volumeSlider.value = this.volume;
        this.volumeDisplay.textContent = `${Math.round(this.volume)}%`;
        
        // Mode buttons
        this.shuffleBtn.className = `btn ${this.shuffleMode ? 'btn-warning' : 'btn-outline-light'}`;
        this.repeatBtn.className = `btn ${this.repeatMode ? 'btn-success' : 'btn-outline-light'}`;
        
        this.updateControlsState();
    }
    
    updateControlsState() {
        const hasPlaylist = this.playlist.length > 0;
        const hasSong = this.currentSong !== null;
        
        this.playPauseBtn.disabled = !hasPlaylist;
        this.stopBtn.disabled = !hasSong;
        this.prevBtn.disabled = !hasPlaylist;
        this.nextBtn.disabled = !hasPlaylist;
    }
    
    async playSong(index) {
        try {
            const response = await fetch(`/api/play/${index}`, { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.updatePlayerState(data);
                this.updatePlaylistUI();
                this.showSuccess(`"${data.current_song.title}" çalınıyor`);
            } else {
                this.showError(data.error || 'Şarkı çalınamadı');
            }
        } catch (error) {
            console.error('Şarkı çalma hatası:', error);
            this.showError('Şarkı çalınamadı');
        }
    }
    
    async togglePlayPause() {
        if (this.currentSong) {
            try {
                const response = await fetch('/api/pause', { method: 'POST' });
                const data = await response.json();
                
                if (data.success) {
                    this.isPlaying = data.is_playing;
                    this.updateUI();
                    this.updatePlaylistUI();
                }
            } catch (error) {
                console.error('Pause/play hatası:', error);
                this.showError('İşlem gerçekleştirilemedi');
            }
        } else if (this.playlist.length > 0) {
            // İlk şarkıyı çal
            this.playSong(0);
        }
    }
    
    async stopMusic() {
        try {
            const response = await fetch('/api/stop', { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.isPlaying = false;
                this.updateUI();
                this.updatePlaylistUI();
                this.progressBar.style.width = '0%';
                this.currentTime.textContent = '0:00';
            }
        } catch (error) {
            console.error('Stop hatası:', error);
            this.showError('İşlem gerçekleştirilemedi');
        }
    }
    
    async nextSong() {
        try {
            const response = await fetch('/api/next', { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.updatePlayerState(data);
                this.updatePlaylistUI();
            }
        } catch (error) {
            console.error('Sonraki şarkı hatası:', error);
            this.showError('Sonraki şarkıya geçilemedi');
        }
    }
    
    async previousSong() {
        try {
            const response = await fetch('/api/previous', { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.updatePlayerState(data);
                this.updatePlaylistUI();
            }
        } catch (error) {
            console.error('Önceki şarkı hatası:', error);
            this.showError('Önceki şarkıya geçilemedi');
        }
    }
    
    async setVolume(value) {
        const volume = parseFloat(value) / 100;
        try {
            const response = await fetch(`/api/volume/${volume}`, { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.volume = data.volume * 100;
                this.volumeDisplay.textContent = `${Math.round(this.volume)}%`;
            }
        } catch (error) {
            console.error('Volume hatası:', error);
            this.showError('Ses seviyesi ayarlanamadı');
        }
    }
    
    async toggleShuffle() {
        try {
            const response = await fetch('/api/toggle_shuffle', { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.shuffleMode = data.shuffle;
                this.updateUI();
                this.showSuccess(this.shuffleMode ? 'Karıştırma açık' : 'Karıştırma kapalı');
            }
        } catch (error) {
            console.error('Shuffle hatası:', error);
            this.showError('Karıştırma modu değiştirilemedi');
        }
    }
    
    async toggleRepeat() {
        try {
            const response = await fetch('/api/toggle_repeat', { method: 'POST' });
            const data = await response.json();
            
            if (data.success) {
                this.repeatMode = data.repeat;
                this.updateUI();
                this.showSuccess(this.repeatMode ? 'Tekrar açık' : 'Tekrar kapalı');
            }
        } catch (error) {
            console.error('Repeat hatası:', error);
            this.showError('Tekrar modu değiştirilemedi');
        }
    }
    
    async deleteSong(filename) {
        if (!confirm(`"${filename}" dosyasını silmek istediğinizden emin misiniz?`)) {
            return;
        }
        
        try {
            const response = await fetch(`/api/delete/${encodeURIComponent(filename)}`, { 
                method: 'DELETE' 
            });
            const data = await response.json();
            
            if (data.success) {
                this.showSuccess('Dosya silindi');
                this.loadPlaylist(); // Refresh playlist
            } else {
                this.showError(data.error || 'Dosya silinemedi');
            }
        } catch (error) {
            console.error('Delete hatası:', error);
            this.showError('Dosya silinemedi');
        }
    }
    
    handleFileSelect(e) {
        const files = Array.from(e.target.files);
        this.uploadFiles(files);
    }
    
    handleDragOver(e) {
        e.preventDefault();
        this.dropZone.classList.add('drag-over');
    }
    
    handleDragLeave(e) {
        e.preventDefault();
        this.dropZone.classList.remove('drag-over');
    }
    
    handleDrop(e) {
        e.preventDefault();
        this.dropZone.classList.remove('drag-over');
        
        const files = Array.from(e.dataTransfer.files).filter(
            file => file.type === 'audio/mpeg' || file.name.toLowerCase().endsWith('.mp3')
        );
        
        if (files.length === 0) {
            this.showError('Lütfen sadece MP3 dosyaları yükleyin');
            return;
        }
        
        this.uploadFiles(files);
    }
    
    async uploadFiles(files) {
        const totalFiles = files.length;
        let uploadedFiles = 0;
        
        this.uploadProgress.classList.remove('d-none');
        
        for (const file of files) {
            try {
                const formData = new FormData();
                formData.append('file', file);
                
                this.uploadStatus.textContent = `Yükleniyor: ${file.name}`;
                
                const response = await fetch('/upload', {
                    method: 'POST',
                    body: formData
                });
                
                const data = await response.json();
                
                if (data.success) {
                    uploadedFiles++;
                    this.showSuccess(`"${file.name}" yüklendi`);
                } else {
                    this.showError(`"${file.name}": ${data.error}`);
                }
                
                // Progress update
                const progress = (uploadedFiles / totalFiles) * 100;
                this.uploadProgress.querySelector('.progress-bar').style.width = `${progress}%`;
                
            } catch (error) {
                console.error('Upload hatası:', error);
                this.showError(`"${file.name}" yüklenemedi`);
            }
        }
        
        this.uploadStatus.textContent = `${uploadedFiles}/${totalFiles} dosya yüklendi`;
        
        setTimeout(() => {
            this.uploadProgress.classList.add('d-none');
            this.uploadProgress.querySelector('.progress-bar').style.width = '0%';
            this.loadPlaylist(); // Refresh playlist
            
            // Reset file input
            this.fileInput.value = '';
        }, 2000);
    }
    
    startStatusUpdates() {
        // Her 5 saniyede bir durumu kontrol et
        this.statusUpdateInterval = setInterval(async () => {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                this.updatePlayerState(data);
                
                // UI güncelle ama playlist'i yeniden yükleme (performans için)
                this.updateUI();
                
            } catch (error) {
                console.error('Status update hatası:', error);
            }
        }, 5000);
    }
    
    showSuccess(message) {
        this.successMessage.textContent = message;
        this.successToast.show();
    }
    
    showError(message) {
        this.errorMessage.textContent = message;
        this.errorToast.show();
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize player when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.mp3Player = new MP3Player();
});