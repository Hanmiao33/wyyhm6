import media from '@ohos.multimedia.media';
import { Song, PlayMode, PlayerState, LyricLine, AudioQuality, SongQualityInfo } from '../models/MusicModel';
import { ApiService } from './ApiService';
import { AudioSessionService, MediaCallbacks } from './AudioSessionService';

export class PlayerService {
  private static instance: PlayerService;
  private avPlayer: media.AVPlayer | null = null;
  private apiService: ApiService;
  private audioSessionService: AudioSessionService;

  private currentSong: Song | null = null;
  private playlist: Song[] = [];
  private currentIndex: number = -1;
  private playMode: PlayMode = PlayMode.SEQUENCE;
  private playerState: PlayerState = PlayerState.STOPPED;
  private currentPosition: number = 0;
  private duration: number = 0;
  private lyrics: LyricLine[] = [];
  private currentLyricIndex: number = -1;
  private currentQuality: AudioQuality = AudioQuality.EXHIGH;

  // 使用数组支持多个监听器
  private stateChangeListeners: ((state: PlayerState) => void)[] = [];
  private songChangeListeners: ((song: Song | null) => void)[] = [];
  private progressChangeListeners: ((position: number, duration: number) => void)[] = [];
  private lyricChangeListeners: ((index: number, text: string) => void)[] = [];

  private constructor() {
    this.apiService = ApiService.getInstance();
    this.audioSessionService = AudioSessionService.getInstance();

    // 注册媒体控制回调，使实况窗/通知栏的控制按钮能操控播放器
    const mediaCallbacks: MediaCallbacks = {
      onPlay: (): void => { this.play(); },
      onPause: (): void => { this.pause(); },
      onNext: (): void => { this.playNext(); },
      onPrevious: (): void => { this.playPrevious(); },
      onSeek: (position: number): void => { this.seekTo(position); },
    };
    this.audioSessionService.setMediaCallbacks(mediaCallbacks);
  }

  public static getInstance(): PlayerService {
    if (!PlayerService.instance) {
      PlayerService.instance = new PlayerService();
    }
    return PlayerService.instance;
  }

  // 添加状态变化监听器
  addStateChangeListener(listener: (state: PlayerState) => void): void {
    this.stateChangeListeners.push(listener);
  }

  // 移除状态变化监听器
  removeStateChangeListener(listener: (state: PlayerState) => void): void {
    const index = this.stateChangeListeners.indexOf(listener);
    if (index > -1) {
      this.stateChangeListeners.splice(index, 1);
    }
  }

  // 添加歌曲变化监听器
  addSongChangeListener(listener: (song: Song | null) => void): void {
    this.songChangeListeners.push(listener);
  }

  // 移除歌曲变化监听器
  removeSongChangeListener(listener: (song: Song | null) => void): void {
    const index = this.songChangeListeners.indexOf(listener);
    if (index > -1) {
      this.songChangeListeners.splice(index, 1);
    }
  }

  // 添加进度变化监听器
  addProgressChangeListener(listener: (position: number, duration: number) => void): void {
    this.progressChangeListeners.push(listener);
  }

  // 移除进度变化监听器
  removeProgressChangeListener(listener: (position: number, duration: number) => void): void {
    const index = this.progressChangeListeners.indexOf(listener);
    if (index > -1) {
      this.progressChangeListeners.splice(index, 1);
    }
  }

  // 添加歌词变化监听器
  addLyricChangeListener(listener: (index: number, text: string) => void): void {
    this.lyricChangeListeners.push(listener);
  }

  // 移除歌词变化监听器
  removeLyricChangeListener(listener: (index: number, text: string) => void): void {
    const index = this.lyricChangeListeners.indexOf(listener);
    if (index > -1) {
      this.lyricChangeListeners.splice(index, 1);
    }
  }

  // 通知所有状态变化监听器
  private notifyStateChange(state: PlayerState): void {
    for (const listener of this.stateChangeListeners) {
      listener(state);
    }
  }

  // 通知所有歌曲变化监听器
  private notifySongChange(song: Song | null): void {
    for (const listener of this.songChangeListeners) {
      listener(song);
    }
  }

  // 通知所有进度变化监听器
  private notifyProgressChange(position: number, duration: number): void {
    for (const listener of this.progressChangeListeners) {
      listener(position, duration);
    }
  }

  // 通知所有歌词变化监听器
  private notifyLyricChange(index: number, text: string): void {
    for (const listener of this.lyricChangeListeners) {
      listener(index, text);
    }
  }

  // 保持向后兼容的方法
  setStateChangeCallback(callback: (state: PlayerState) => void) {
    this.stateChangeListeners = [callback];
  }

  setSongChangeCallback(callback: (song: Song | null) => void) {
    this.songChangeListeners = [callback];
  }

  setProgressChangeCallback(callback: (position: number, duration: number) => void) {
    this.progressChangeListeners = [callback];
  }

  setLyricChangeCallback(callback: (index: number, text: string) => void) {
    this.lyricChangeListeners = [callback];
  }

  private async initPlayer() {
    console.info('initPlayer() called');
    if (this.avPlayer) {
      console.info('Releasing existing player');
      await this.avPlayer.release();
    }

    console.info('Creating new AVPlayer');
    this.avPlayer = await media.createAVPlayer();
    console.info('AVPlayer created:', this.avPlayer !== null);

    this.avPlayer.on('stateChange', (state: string) => {
      console.info('Player state changed:', state);
      switch (state) {
        case 'initialized':
          console.info('Player initialized, preparing...');
          this.avPlayer?.prepare();
          break;
        case 'prepared':
          console.info('Player prepared, starting playback');
          this.avPlayer?.play();
          break;
        case 'playing':
          console.info('Player is now playing');
          this.playerState = PlayerState.PLAYING;
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
        case 'paused':
          console.info('Player paused');
          this.playerState = PlayerState.PAUSED;
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
        case 'stopped':
          console.info('Player stopped');
          this.playerState = PlayerState.STOPPED;
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
        case 'completed':
          console.info('Playback completed, playing next');
          this.playNext();
          break;
        case 'error':
          console.error('Player error occurred');
          this.playerState = PlayerState.STOPPED;
          this.notifyStateChange(this.playerState);
          this.audioSessionService.updatePlaybackState(this.playerState, this.currentPosition, this.duration);
          break;
      }
    });

    this.avPlayer.on('timeUpdate', (timeMs: number) => {
      this.currentPosition = timeMs / 1000;
      this.notifyProgressChange(this.currentPosition, this.duration);
      this.audioSessionService.updateProgress(this.currentPosition, this.duration);
      this.updateLyric();
    });

    console.info('initPlayer() completed');
  }

  private updateLyric() {
    if (this.lyrics.length === 0) return;

    let newIndex = -1;
    for (let i = this.lyrics.length - 1; i >= 0; i--) {
      if (this.currentPosition >= this.lyrics[i].time) {
        newIndex = i;
        break;
      }
    }

    if (newIndex !== this.currentLyricIndex) {
      this.currentLyricIndex = newIndex;
      const text = newIndex >= 0 ? this.lyrics[newIndex].text : '';
      this.notifyLyricChange(newIndex, text);
    }
  }

  async playSong(song: Song): Promise<void> {
    console.info('playSong() called for:', song.name, 'id:', song.id);
    try {
      console.info('Initializing player...');
      await this.initPlayer();

      this.currentSong = song;
      this.notifySongChange(song);
      this.audioSessionService.updateMetadata(song);
      this.playerState = PlayerState.LOADING;
      this.notifyStateChange(this.playerState);
      this.audioSessionService.updatePlaybackState(this.playerState, 0, song.duration / 1000);

      // 获取播放链接
      console.info('Getting song URL for id:', song.id, 'quality:', this.currentQuality);
      const url: string = await this.apiService.getSongUrl(song.id, this.currentQuality);
      console.info('Song URL result:', url);

      if (url && this.avPlayer) {
        this.currentSong.url = url;
        console.info('Setting avPlayer.url:', url);
        this.avPlayer.url = url;
        this.duration = song.duration / 1000;
        console.info('Duration set to:', this.duration);
      } else {
        console.error('No URL or player not initialized, url:', url, 'avPlayer:', this.avPlayer !== null);
        this.playerState = PlayerState.STOPPED;
        this.notifyStateChange(this.playerState);
      }

      // 获取歌词
      console.info('Getting lyrics...');
      this.lyrics = await this.apiService.getLyric(song.id);
      this.currentLyricIndex = -1;
      console.info('playSong() completed');
    } catch (error) {
      console.error('Play song error:', error);
      this.playerState = PlayerState.STOPPED;
      this.notifyStateChange(this.playerState);
    }
  }

  async play() {
    console.info('play() called, avPlayer:', this.avPlayer !== null, 'state:', this.playerState, 'currentSong:', this.currentSong ? this.currentSong.name : 'null');

    // 如果正在加载或播放中，不重复操作
    if (this.playerState === PlayerState.LOADING || this.playerState === PlayerState.PLAYING) {
      console.info('Already loading or playing, skipping');
      return;
    }

    if (this.avPlayer && this.playerState === PlayerState.PAUSED) {
      console.info('Resuming paused playback');
      this.avPlayer.play();
    } else if (this.currentSong) {
      console.info('Starting playback for:', this.currentSong.name);
      await this.playSong(this.currentSong);
    } else {
      console.warn('No current song to play');
    }
  }

  pause() {
    if (this.avPlayer && this.playerState === PlayerState.PLAYING) {
      this.avPlayer.pause();
    }
  }

  stop() {
    if (this.avPlayer) {
      this.avPlayer.stop();
    }
  }

  async playNext() {
    if (this.playlist.length === 0) return;

    let nextIndex: number;
    switch (this.playMode) {
      case PlayMode.RANDOM:
        nextIndex = Math.floor(Math.random() * this.playlist.length);
        break;
      case PlayMode.SINGLE:
        nextIndex = this.currentIndex;
        break;
      default:
        nextIndex = (this.currentIndex + 1) % this.playlist.length;
    }

    this.currentIndex = nextIndex;
    await this.playSong(this.playlist[nextIndex]);
  }

  async playPrevious() {
    if (this.playlist.length === 0) return;

    let prevIndex: number;
    switch (this.playMode) {
      case PlayMode.RANDOM:
        prevIndex = Math.floor(Math.random() * this.playlist.length);
        break;
      default:
        prevIndex = (this.currentIndex - 1 + this.playlist.length) % this.playlist.length;
    }

    this.currentIndex = prevIndex;
    await this.playSong(this.playlist[prevIndex]);
  }

  seekTo(position: number) {
    if (this.avPlayer) {
      this.avPlayer.seek(position * 1000);
    }
  }

  setPlayMode(mode: PlayMode) {
    this.playMode = mode;
  }

  setPlaylist(songs: Song[], startIndex: number = 0) {
    this.playlist = songs;
    this.currentIndex = startIndex;
  }

  getCurrentSong(): Song | null {
    return this.currentSong;
  }

  getPlayerState(): PlayerState {
    return this.playerState;
  }

  getPlayMode(): PlayMode {
    return this.playMode;
  }

  getCurrentPosition(): number {
    return this.currentPosition;
  }

  getDuration(): number {
    return this.duration;
  }

  getPlaylist(): Song[] {
    return this.playlist;
  }

  getCurrentIndex(): number {
    return this.currentIndex;
  }

  getCurrentLyricIndex(): number {
    return this.currentLyricIndex;
  }

  getLyrics(): LyricLine[] {
    return this.lyrics;
  }

  getQuality(): AudioQuality {
    return this.currentQuality;
  }

  setQuality(quality: AudioQuality) {
    this.currentQuality = quality;
    // 如果当前有歌曲在播放，重新加载
    if (this.currentSong && (this.playerState === PlayerState.PLAYING || this.playerState === PlayerState.PAUSED)) {
      this.playSong(this.currentSong);
    }
  }

  getAvailableQualities(): SongQualityInfo[] {
    if (this.currentSong && this.currentSong.availableQualities) {
      return this.currentSong.availableQualities;
    }
    // 默认返回所有标准音质
    return [
      { level: AudioQuality.STANDARD, br: 128000, size: 0, sr: 44100 },
      { level: AudioQuality.HIGHER, br: 192000, size: 0, sr: 44100 },
      { level: AudioQuality.EXHIGH, br: 320000, size: 0, sr: 48000 },
      { level: AudioQuality.LOSSLESS, br: 999000, size: 0, sr: 48000 },
    ];
  }

  async release() {
    if (this.avPlayer) {
      await this.avPlayer.release();
      this.avPlayer = null;
    }
  }
}
