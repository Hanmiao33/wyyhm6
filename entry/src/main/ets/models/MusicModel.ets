export interface Song {
  id: number;
  name: string;
  artist: string;
  album: string;
  albumId: number;
  duration: number;
  url: string;
  coverUrl: string;
  lyric: string;
  availableQualities?: SongQualityInfo[];
}

export interface Playlist {
  id: number;
  name: string;
  coverUrl: string;
  songCount: number;
  songs: Song[];
}

export interface PlaylistInfo {
  id: number;
  name: string;
  coverUrl: string;
  songCount: number;
  playCount: number;
  creator: string;
  isAlbum?: boolean;
}

export interface PlaylistSearchResult {
  playlists: PlaylistInfo[];
  total: number;
}

export interface PlaylistDetail {
  info: PlaylistInfo;
  songs: Song[];
}

export interface SearchResult {
  songs: Song[];
  total: number;
  page: number;
}

export interface LyricLine {
  time: number;
  text: string;
}

export enum PlayMode {
  SEQUENCE = 'sequence',
  LOOP = 'loop',
  RANDOM = 'random',
  SINGLE = 'single'
}

export enum PlayerState {
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  LOADING = 'loading'
}

export enum AudioQuality {
  STANDARD = 128000,   // 标准
  HIGHER = 192000,     // 较高
  EXHIGH = 320000,     // 极高
  LOSSLESS = 999000,   // 无损
}

export interface SongQualityInfo {
  level: AudioQuality;
  br: number;
  size: number;
  sr: number;
}

export enum EffectLevel {
  OFF = 0,
  LOW = 1,
  MEDIUM = 2,
  HIGH = 3
}
