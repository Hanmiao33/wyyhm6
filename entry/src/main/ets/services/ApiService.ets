import { Song, SearchResult, LyricLine, AudioQuality, SongQualityInfo, PlaylistInfo, PlaylistSearchResult, PlaylistDetail } from '../models/MusicModel';
import http from '@ohos.net.http';
import { CacheService } from './CacheService';

const BASE_URL: string = 'https://music.163.com/api/cloudsearch/pc';
const LYRIC_BASE: string = 'https://music.163.com/api/song/lyric';

interface ArtistItem {
  id: number;
  name: string;
}

interface AlbumItem {
  id: number;
  name: string;
  picUrl: string;
}

interface QualityDetail {
  br: number;
  size: number;
  sr: number;
}

interface SongItem {
  id: number;
  name: string;
  ar: ArtistItem[];
  al: AlbumItem;
  dt: number;
  l?: QualityDetail;
  m?: QualityDetail;
  h?: QualityDetail;
  sq?: QualityDetail;
  hr?: QualityDetail;
}

interface SearchResultResult {
  songs: SongItem[];
  songCount: number;
}

interface SearchResultData {
  result: SearchResultResult;
  code: number;
}

interface LyricLrc {
  lyric: string;
}

interface LyricData {
  lrc: LyricLrc;
  code: number;
}

interface DetailArtistItem {
  id: number;
  name: string;
}

interface DetailAlbumItem {
  id: number;
  name: string;
  picUrl: string;
  picId: number;
}

interface DetailSongItem {
  id: number;
  name: string;
  artists: DetailArtistItem[];
  album: DetailAlbumItem;
  duration: number;
}

interface SongDetailData {
  songs: DetailSongItem[];
}

interface SongUrlItem {
  id: number;
  url: string;
  br: number;
  level: string;
  type: string;
}

interface SongUrlData {
  code: number;
  data: SongUrlItem[];
}

// ===== 歌单 API 响应类型 =====

interface PlaylistSearchApiCreator {
  nickname: string;
}

interface PlaylistSearchApiItem {
  id: number;
  name: string;
  coverImgUrl: string;
  trackCount: number;
  playCount: number;
  creator: PlaylistSearchApiCreator;
}

interface PlaylistSearchApiResult {
  playlists: PlaylistSearchApiItem[];
  playlistCount: number;
}

interface PlaylistSearchApiResponse {
  code: number;
  result: PlaylistSearchApiResult;
}

interface PlaylistDetailApiCreator {
  nickname: string;
}

interface PlaylistDetailTrackArtist {
  id: number;
  name: string;
}

interface PlaylistDetailTrackAlbum {
  id: number;
  name: string;
  picUrl: string;
}

interface PlaylistDetailTrack {
  id: number;
  name: string;
  ar: PlaylistDetailTrackArtist[];
  al: PlaylistDetailTrackAlbum;
  dt: number;
}

interface PlaylistDetailTrackId {
  id: number;
}

interface PlaylistDetailApiData {
  id: number;
  name: string;
  coverImgUrl: string;
  trackCount: number;
  playCount: number;
  creator: PlaylistDetailApiCreator;
  tracks: PlaylistDetailTrack[];
  trackIds: PlaylistDetailTrackId[];
}

interface PlaylistDetailApiResponse {
  code: number;
  playlist: PlaylistDetailApiData;
}

interface PersonalizedPlaylistItem {
  id: number;
  name: string;
  picUrl: string;
  trackCount: number;
  playCount: number;
}

interface PersonalizedApiResponse {
  code: number;
  result: PersonalizedPlaylistItem[];
}

interface TopPlaylistApiCreator {
  nickname: string;
}

interface TopPlaylistApiItem {
  id: number;
  name: string;
  coverImgUrl: string;
  trackCount: number;
  playCount: number;
  creator: TopPlaylistApiCreator;
}

interface TopPlaylistApiResponse {
  code: number;
  playlists: TopPlaylistApiItem[];
}

// ===== 专辑推荐 API =====

interface NewAlbumArtist {
  id: number;
  name: string;
}

interface NewAlbumItem {
  id: number;
  name: string;
  picUrl: string;
  artistName: string;
  artists: NewAlbumArtist[];
}

interface NewAlbumApiResponse {
  code: number;
  result: NewAlbumItem[];
}

export class ApiService {
  private static instance: ApiService;
  private httpRequest: http.HttpRequest;
  private cache: CacheService = CacheService.getInstance();

  // 缓存 TTL（毫秒）
  private static readonly TTL_SEARCH = 3 * 60 * 1000;      // 搜索结果 3 分钟
  private static readonly TTL_LYRIC = 30 * 60 * 1000;       // 歌词 30 分钟
  private static readonly TTL_SONG_DETAIL = 15 * 60 * 1000;  // 歌曲详情 15 分钟
  private static readonly TTL_SONG_URL = 5 * 60 * 1000;      // 播放链接 5 分钟
  private static readonly TTL_PLAYLIST = 10 * 60 * 1000;     // 歌单详情 10 分钟
  private static readonly TTL_PLAYLIST_SEARCH = 5 * 60 * 1000; // 歌单搜索 5 分钟
  private static readonly TTL_TOP_PLAYLIST = 10 * 60 * 1000; // 热门歌单 10 分钟

  private constructor() {
    this.httpRequest = http.createHttp();
  }

  public static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService();
    }
    return ApiService.instance;
  }

  // 构建通用请求头 — 模拟浏览器行为，避免被 WAF 拦截
  private buildCommonHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Referer'] = 'https://music.163.com';
    headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    headers['Accept'] = 'application/json, text/plain, */*';
    headers['Accept-Language'] = 'zh-CN,zh;q=0.9';
    headers['Cookie'] = 'appver=2.0.2';
    return headers;
  }

  async searchMusic(keyword: string, page: number = 1, limit: number = 20): Promise<SearchResult> {
    const cacheKey = `search:${keyword}:p${page}:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as SearchResult;
    }

    try {
      const url: string = BASE_URL;
      const offset: number = (page - 1) * limit;
      const body: string = `s=${encodeURIComponent(keyword)}&type=1&limit=${limit}&offset=${offset}`;

      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: SearchResultData = JSON.parse(response.result as string) as SearchResultData;
        if (data.code === 200 && data.result && data.result.songs) {
          const songs: Song[] = data.result.songs.map((item: SongItem): Song => {
            const artistNames: string = item.ar ? item.ar.map((a: ArtistItem): string => a.name).join('/') : '未知';
            const albumName: string = item.al ? item.al.name : '未知';
            const coverUrl: string = (item.al && item.al.picUrl) ? item.al.picUrl.replace('http://', 'https://') : '';

            const qualities: SongQualityInfo[] = [];
            if (item.l) {
              qualities.push({ level: AudioQuality.STANDARD, br: item.l.br, size: item.l.size, sr: item.l.sr });
            }
            if (item.m) {
              qualities.push({ level: AudioQuality.HIGHER, br: item.m.br, size: item.m.size, sr: item.m.sr });
            }
            if (item.h) {
              qualities.push({ level: AudioQuality.EXHIGH, br: item.h.br, size: item.h.size, sr: item.h.sr });
            }
            if (item.sq) {
              qualities.push({ level: AudioQuality.LOSSLESS, br: item.sq.br, size: item.sq.size, sr: item.sq.sr });
            }

            return {
              id: item.id,
              name: item.name,
              artist: artistNames,
              album: albumName,
              albumId: item.al ? item.al.id : 0,
              duration: item.dt || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: '',
              availableQualities: qualities
            };
          });

          const result: SearchResult = { songs, total: data.result.songCount || 0, page };
          this.cache.set(cacheKey, result, ApiService.TTL_SEARCH);
          return result;
        }
      }
      return { songs: [], total: 0, page };
    } catch (error) {
      console.error('Search music error:', error);
      return { songs: [], total: 0, page };
    }
  }

  async getSongUrl(songId: number, quality: AudioQuality = AudioQuality.EXHIGH): Promise<string> {
    const cacheKey = `songurl:${songId}:${quality}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as string;
    }

    try {
      const url: string = `https://music.163.com/api/song/enhance/player/url?id=${songId}&ids=[${songId}]&br=${quality}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildCommonHeaders()
      });

      if (response.responseCode === 200) {
        const data: SongUrlData = JSON.parse(response.result as string) as SongUrlData;
        if (data.code === 200 && data.data && data.data.length > 0) {
          const songData: SongUrlItem = data.data[0];
          if (songData.url) {
            const songUrl: string = songData.url;
            const finalUrl: string = songUrl.replace('http://', 'https://');
            console.info('Got song url, br:', songData.br, 'level:', songData.level, 'type:', songData.type);
            this.cache.set(cacheKey, finalUrl, ApiService.TTL_SONG_URL);
            return finalUrl;
          }
        }
      }

      // 高音质失败时，尝试标准音质
      if (quality !== AudioQuality.STANDARD) {
        console.error('Failed to get high quality url, trying standard quality');
        return this.getSongUrl(songId, AudioQuality.STANDARD);
      }

      console.error('Failed to get song url for id:', songId);
      return '';
    } catch (error) {
      console.error('Get song url error:', error);
      return '';
    }
  }

  async getLyric(songId: number): Promise<LyricLine[]> {
    const cacheKey = `lyric:${songId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as LyricLine[];
    }

    try {
      const url: string = `${LYRIC_BASE}?id=${songId}&lv=1&kv=1&tv=-1`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildCommonHeaders()
      });

      if (response.responseCode === 200) {
        const data: LyricData = JSON.parse(response.result as string) as LyricData;
        if (data.code === 200 && data.lrc && data.lrc.lyric) {
          const lyrics = this.parseLyric(data.lrc.lyric);
          this.cache.set(cacheKey, lyrics, ApiService.TTL_LYRIC);
          return lyrics;
        }
      }
      return [];
    } catch (error) {
      console.error('Get lyric error:', error);
      return [];
    }
  }

  private parseLyric(lyricStr: string): LyricLine[] {
    const lines: LyricLine[] = [];
    const lyricLines: string[] = lyricStr.split('\n');

    for (const line of lyricLines) {
      const match: RegExpMatchArray | null = line.match(/\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/);
      if (match) {
        const minutes: number = parseInt(match[1]);
        const seconds: number = parseInt(match[2]);
        const milliseconds: number = parseInt(match[3]);
        const time: number = minutes * 60 + seconds + milliseconds / 1000;
        const text: string = match[4].trim();
        if (text) {
          lines.push({ time, text });
        }
      }
    }

    return lines.sort((a: LyricLine, b: LyricLine): number => a.time - b.time);
  }

  async getSongDetail(songId: number): Promise<Song | null> {
    const cacheKey = `detail:${songId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as Song;
    }

    try {
      const url: string = `https://music.163.com/api/song/detail?id=${songId}&ids=[${songId}]`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildCommonHeaders()
      });

      if (response.responseCode === 200) {
        const data: SongDetailData = JSON.parse(response.result as string) as SongDetailData;
        if (data && data.songs && data.songs.length > 0) {
          const songData: DetailSongItem = data.songs[0];
          const artistNames: string = songData.artists ? songData.artists.map((a: DetailArtistItem): string => a.name).join('/') : '未知';
          const albumName: string = songData.album ? songData.album.name : '未知';
          const coverUrl: string = songData.album ? (songData.album.picUrl || '') : '';

          const song: Song = {
            id: songData.id,
            name: songData.name,
            artist: artistNames,
            album: albumName,
            albumId: songData.album ? songData.album.id : 0,
            duration: songData.duration || 0,
            url: '',
            coverUrl: coverUrl,
            lyric: ''
          };
          this.cache.set(cacheKey, song, ApiService.TTL_SONG_DETAIL);
          return song;
        }
      }
      return null;
    } catch (error) {
      console.error('Get song detail error:', error);
      return null;
    }
  }

  // ===== 歌单相关 API =====

  // 搜索歌单
  async searchPlaylists(keyword: string, limit: number = 10): Promise<PlaylistSearchResult> {
    const cacheKey = `plsearch:${keyword}:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistSearchResult;
    }

    try {
      const url: string = BASE_URL;
      const body: string = `s=${encodeURIComponent(keyword)}&type=1000&limit=${limit}&offset=0`;

      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: PlaylistSearchApiResponse = JSON.parse(response.result as string) as PlaylistSearchApiResponse;
        if (data.code === 200 && data.result && data.result.playlists) {
          const playlists: PlaylistInfo[] = data.result.playlists.map((item: PlaylistSearchApiItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.coverImgUrl || '').replace('http://', 'https://'),
              songCount: item.trackCount || 0,
              playCount: item.playCount || 0,
              creator: item.creator ? item.creator.nickname : '未知'
            };
          });
          const result: PlaylistSearchResult = { playlists, total: data.result.playlistCount || 0 };
          this.cache.set(cacheKey, result, ApiService.TTL_PLAYLIST_SEARCH);
          return result;
        }
      }
      return { playlists: [], total: 0 };
    } catch (error) {
      console.error('Search playlists error:', error);
      return { playlists: [], total: 0 };
    }
  }

  // 获取歌单详情（歌曲列表）
  async getPlaylistDetail(playlistId: number): Promise<PlaylistDetail | null> {
    const cacheKey = `pldetail:${playlistId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistDetail;
    }

    try {
      const url: string = `https://music.163.com/api/v3/playlist/detail`;
      const body: string = `id=${playlistId}&n=1000&s=0`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: PlaylistDetailApiResponse = JSON.parse(response.result as string) as PlaylistDetailApiResponse;
        if (data.code === 200 && data.playlist) {
          const pl: PlaylistDetailApiData = data.playlist;

          // 先用接口返回的 tracks（通常只有前 10 首）
          let songs: Song[] = pl.tracks.map((track: PlaylistDetailTrack): Song => {
            const artistNames: string =
            track.ar && track.ar.length > 0 ? track.ar.map((a: PlaylistDetailTrackArtist): string => a.name).join('/') :
              '未知';
            const albumName: string = track.al ? track.al.name : '未知';
            const coverUrl: string = track.al ? (track.al.picUrl || '').replace('http://', 'https://') : '';

            return {
              id: track.id,
              name: track.name,
              artist: artistNames,
              album: albumName,
              albumId: track.al ? track.al.id : 0,
              duration: track.dt || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: ''
            };
          });

          // 如果 tracks 不完整，用 trackIds 分批补全
          const totalCount: number = pl.trackCount || 0;
          if (songs.length < totalCount && pl.trackIds && pl.trackIds.length > 0) {
            const existingIds: Set<number> = new Set();
            for (const s of songs) {
              existingIds.add(s.id);
            }
            // 收集缺失的 trackId
            const missingIds: number[] = [];
            for (const tid of pl.trackIds) {
              if (!existingIds.has(tid.id)) {
                missingIds.push(tid.id);
              }
            }
            // 分批请求（每批最多 100 首）
            const batchSize: number = 100;
            for (let i = 0; i < missingIds.length; i += batchSize) {
              const batch: number[] = missingIds.slice(i, i + batchSize);
              const batchSongs: Song[] = await this.batchGetSongDetails(batch);
              songs = songs.concat(batchSongs);
            }
          }

          const result: PlaylistDetail = {
            info: {
              id: pl.id,
              name: pl.name,
              coverUrl: (pl.coverImgUrl || '').replace('http://', 'https://'),
              songCount: totalCount,
              playCount: pl.playCount || 0,
              creator: pl.creator ? pl.creator.nickname : '未知'
            },
            songs
          };
          this.cache.set(cacheKey, result, ApiService.TTL_PLAYLIST);
          return result;
        }
      }
      return null;
    } catch (error) {
      console.error('Get playlist detail error:', error);
      return null;
    }
  }

  // 批量获取歌曲详情（每批最多 100 首）
  private async batchGetSongDetails(ids: number[]): Promise<Song[]> {
    try {
      const idsStr: string = JSON.stringify(ids);
      const url: string = `https://music.163.com/api/song/detail`;
      const body: string = `ids=${encodeURIComponent(idsStr)}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          'Cookie': 'appver=2.0.2'
        },
        extraData: body
      });

      if (response.responseCode === 200) {
        const data: SongDetailData = JSON.parse(response.result as string) as SongDetailData;
        if (data && data.songs) {
          return data.songs.map((item: DetailSongItem): Song => {
            const artistNames: string = item.artists ? item.artists.map((a: DetailArtistItem): string => a.name).join('/') : '未知';
            const albumName: string = item.album ? item.album.name : '未知';
            const coverUrl: string = item.album ? (item.album.picUrl || '').replace('http://', 'https://') : '';
            return {
              id: item.id,
              name: item.name,
              artist: artistNames,
              album: albumName,
              albumId: item.album ? item.album.id : 0,
              duration: item.duration || 0,
              url: '',
              coverUrl: coverUrl,
              lyric: ''
            };
          });
        }
      }
      return [];
    } catch (error) {
      console.error('Batch get song details error:', error);
      return [];
    }
  }

  // 获取推荐歌单（个性化推荐 + 热门）
  async getPersonalizedPlaylists(limit: number = 10): Promise<PlaylistInfo[]> {
    const cacheKey = `personalized:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistInfo[];
    }

    try {
      const url: string = `https://music.163.com/api/personalized?limit=${limit}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://music.163.com'
        }
      });

      if (response.responseCode === 200) {
        const data: PersonalizedApiResponse = JSON.parse(response.result as string) as PersonalizedApiResponse;
        if (data.code === 200 && data.result) {
          const playlists = data.result.map((item: PersonalizedPlaylistItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.picUrl || '').replace('http://', 'https://'),
              songCount: item.trackCount || 0,
              playCount: item.playCount || 0,
              creator: ''
            };
          });
          this.cache.set(cacheKey, playlists, ApiService.TTL_TOP_PLAYLIST);
          return playlists;
        }
      }
      return [];
    } catch (error) {
      console.error('Get personalized playlists error:', error);
      return [];
    }
  }

  // 获取热门歌单（按分类）
  async getTopPlaylists(category: string = '全部', limit: number = 10): Promise<PlaylistInfo[]> {
    const cacheKey = `top:${category}:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistInfo[];
    }

    try {
      const url: string = `https://music.163.com/api/top/playlist?cat=${encodeURIComponent(category)}&limit=${limit}&order=hot`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://music.163.com'
        }
      });

      if (response.responseCode === 200) {
        const data: TopPlaylistApiResponse = JSON.parse(response.result as string) as TopPlaylistApiResponse;
        if (data.code === 200 && data.playlists) {
          const playlists = data.playlists.map((item: TopPlaylistApiItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.coverImgUrl || '').replace('http://', 'https://'),
              songCount: item.trackCount || 0,
              playCount: item.playCount || 0,
              creator: item.creator ? item.creator.nickname : '未知'
            };
          });
          this.cache.set(cacheKey, playlists, ApiService.TTL_TOP_PLAYLIST);
          return playlists;
        }
      }
      return [];
    } catch (error) {
      console.error('Get top playlists error:', error);
      return [];
    }
  }

  // 获取专辑详情（通过搜索接口，专辑详情需要登录）
  async getAlbumDetail(albumId: number, albumName: string, artistName: string, coverUrl: string): Promise<PlaylistDetail | null> {
    const cacheKey = `album:${albumId}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistDetail;
    }

    try {
      // 用专辑名+歌手名搜索歌曲
      const keyword: string = `${albumName} ${artistName}`;
      const searchResult = await this.searchMusic(keyword, 1, 30);

      if (searchResult.songs.length > 0) {
        // 过滤：只保留专辑名或歌手名匹配的歌曲
        const filtered: Song[] = searchResult.songs.filter((song: Song): boolean => {
          const artistMatch: boolean = song.artist.includes(artistName) || artistName.includes(song.artist);
          const albumMatch: boolean = song.album.includes(albumName) || albumName.includes(song.album);
          return artistMatch || albumMatch;
        });

        const songs: Song[] = filtered.length > 0 ? filtered : searchResult.songs.slice(0, 10);

        const result: PlaylistDetail = {
          info: {
            id: albumId,
            name: albumName,
            coverUrl: coverUrl,
            songCount: songs.length,
            playCount: 0,
            creator: artistName
          },
          songs
        };
        this.cache.set(cacheKey, result, 10 * 60 * 1000);
        return result;
      }
      return null;
    } catch (error) {
      console.error('Get album detail error:', error);
      return null;
    }
  }

  // 获取新专辑推荐
  async getNewAlbums(limit: number = 8): Promise<PlaylistInfo[]> {
    const cacheKey = `newalbums:l${limit}`;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached) as PlaylistInfo[];
    }

    try {
      const url: string = `https://music.163.com/api/personalized/newalbum?limit=${limit}`;
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://music.163.com'
        }
      });

      if (response.responseCode === 200) {
        const data: NewAlbumApiResponse = JSON.parse(response.result as string) as NewAlbumApiResponse;
        if (data.code === 200 && data.result) {
          const albums: PlaylistInfo[] = data.result.map((item: NewAlbumItem): PlaylistInfo => {
            return {
              id: item.id,
              name: item.name,
              coverUrl: (item.picUrl || '').replace('http://', 'https://'),
              songCount: 0,
              playCount: 0,
              creator: item.artistName || '未知',
              isAlbum: true
            };
          });
          this.cache.set(cacheKey, albums, 10 * 60 * 1000);
          return albums;
        }
      }
      return [];
    } catch (error) {
      console.error('Get new albums error:', error);
      return [];
    }
  }
}
