import { Song, AudioQuality, EffectLevel } from '../models/MusicModel';
import dataStorage from '@ohos.data.preferences';

const SEARCH_HISTORY_KEY = 'search_history';
const PLAY_HISTORY_KEY = 'play_history';
const FAVORITES_KEY = 'favorites';
const AUDIO_QUALITY_KEY = 'audio_quality';
const THEME_DARK_KEY = 'theme_dark';
const EFFECT_LEVEL_KEY = 'effect_level';
const BACKGROUND_IMAGE_KEY = 'bg_image';
const BACKGROUND_OPACITY_KEY = 'bg_opacity';
const MAX_HISTORY_SIZE = 50;
const MAX_FAVORITES_SIZE = 200;

export class StorageService {
  private static instance: StorageService;
  private preferences: dataStorage.Preferences | null = null;
  private context: Context | null = null;

  private constructor() {}

  public static getInstance(): StorageService {
    if (!StorageService.instance) {
      StorageService.instance = new StorageService();
    }
    return StorageService.instance;
  }

  setContext(context: Context) {
    this.context = context;
  }

  private async getPreferences(): Promise<dataStorage.Preferences> {
    if (!this.preferences) {
      if (!this.context) {
        throw new Error('Context not set');
      }
      this.preferences = await dataStorage.getPreferences(this.context, 'music_app_storage');
    }
    return this.preferences;
  }

  // 搜索历史
  async getSearchHistory(): Promise<string[]> {
    try {
      const prefs = await this.getPreferences();
      const history = await prefs.get(SEARCH_HISTORY_KEY, '[]') as string;
      return JSON.parse(history) as string[];
    } catch (e) {
      console.error('Get search history error:', e);
      return [];
    }
  }

  async addSearchHistory(keyword: string): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let history = await this.getSearchHistory();

      // 移除重复项
      history = history.filter((item: string) => item !== keyword);

      // 添加到开头
      history.unshift(keyword);

      // 限制大小
      if (history.length > MAX_HISTORY_SIZE) {
        history = history.slice(0, MAX_HISTORY_SIZE);
      }

      await prefs.put(SEARCH_HISTORY_KEY, JSON.stringify(history));
      await prefs.flush();
    } catch (e) {
      console.error('Add search history error:', e);
    }
  }

  async clearSearchHistory(): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(SEARCH_HISTORY_KEY, '[]');
      await prefs.flush();
    } catch (e) {
      console.error('Clear search history error:', e);
    }
  }

  // 播放历史
  async getPlayHistory(): Promise<Song[]> {
    try {
      const prefs = await this.getPreferences();
      const history = await prefs.get(PLAY_HISTORY_KEY, '[]') as string;
      return JSON.parse(history) as Song[];
    } catch (e) {
      console.error('Get play history error:', e);
      return [];
    }
  }

  async addPlayHistory(song: Song): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let history = await this.getPlayHistory();

      // 移除重复项
      history = history.filter((item: Song) => item.id !== song.id);

      // 添加到开头
      history.unshift(song);

      // 限制大小
      if (history.length > MAX_HISTORY_SIZE) {
        history = history.slice(0, MAX_HISTORY_SIZE);
      }

      await prefs.put(PLAY_HISTORY_KEY, JSON.stringify(history));
      await prefs.flush();
    } catch (e) {
      console.error('Add play history error:', e);
    }
  }

  async clearPlayHistory(): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(PLAY_HISTORY_KEY, '[]');
      await prefs.flush();
    } catch (e) {
      console.error('Clear play history error:', e);
    }
  }

  // 收藏
  async getFavorites(): Promise<Song[]> {
    try {
      const prefs = await this.getPreferences();
      const favorites = await prefs.get(FAVORITES_KEY, '[]') as string;
      return JSON.parse(favorites) as Song[];
    } catch (e) {
      console.error('Get favorites error:', e);
      return [];
    }
  }

  async addFavorite(song: Song): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let favorites = await this.getFavorites();

      // 检查是否已收藏
      const exists = favorites.some((item: Song) => item.id === song.id);
      if (exists) {
        return;
      }

      // 添加到开头
      favorites.unshift(song);

      // 限制大小
      if (favorites.length > MAX_FAVORITES_SIZE) {
        favorites = favorites.slice(0, MAX_FAVORITES_SIZE);
      }

      await prefs.put(FAVORITES_KEY, JSON.stringify(favorites));
      await prefs.flush();
    } catch (e) {
      console.error('Add favorite error:', e);
    }
  }

  async removeFavorite(songId: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      let favorites = await this.getFavorites();

      // 移除指定歌曲
      favorites = favorites.filter((item: Song) => item.id !== songId);

      await prefs.put(FAVORITES_KEY, JSON.stringify(favorites));
      await prefs.flush();
    } catch (e) {
      console.error('Remove favorite error:', e);
    }
  }

  async isFavorite(songId: number): Promise<boolean> {
    try {
      const favorites = await this.getFavorites();
      return favorites.some((item: Song) => item.id === songId);
    } catch (e) {
      console.error('Check favorite error:', e);
      return false;
    }
  }

  async toggleFavorite(song: Song): Promise<boolean> {
    try {
      const isFav = await this.isFavorite(song.id);
      if (isFav) {
        await this.removeFavorite(song.id);
        return false;
      } else {
        await this.addFavorite(song);
        return true;
      }
    } catch (e) {
      console.error('Toggle favorite error:', e);
      return false;
    }
  }

  // 音质偏好
  async getAudioQuality(): Promise<AudioQuality> {
    try {
      const prefs = await this.getPreferences();
      const quality = await prefs.get(AUDIO_QUALITY_KEY, AudioQuality.EXHIGH) as number;
      return quality as AudioQuality;
    } catch (e) {
      console.error('Get audio quality error:', e);
      return AudioQuality.EXHIGH;
    }
  }

  async setAudioQuality(quality: AudioQuality): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(AUDIO_QUALITY_KEY, quality);
      await prefs.flush();
    } catch (e) {
      console.error('Set audio quality error:', e);
    }
  }

  // 主题偏好
  async getThemeDark(): Promise<boolean> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(THEME_DARK_KEY, false) as boolean;
    } catch (e) {
      console.error('Get theme dark error:', e);
      return false;
    }
  }

  async setThemeDark(isDark: boolean): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(THEME_DARK_KEY, isDark);
      await prefs.flush();
    } catch (e) {
      console.error('Set theme dark error:', e);
    }
  }

  // 沉浸光感效果档位
  async getEffectLevel(): Promise<EffectLevel> {
    try {
      const prefs = await this.getPreferences();
      const level = await prefs.get(EFFECT_LEVEL_KEY, EffectLevel.MEDIUM) as number;
      return level as EffectLevel;
    } catch (e) {
      console.error('Get effect level error:', e);
      return EffectLevel.MEDIUM;
    }
  }

  async setEffectLevel(level: EffectLevel): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(EFFECT_LEVEL_KEY, level);
      await prefs.flush();
    } catch (e) {
      console.error('Set effect level error:', e);
    }
  }

  // 背景图片
  async getBgImage(): Promise<string> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(BACKGROUND_IMAGE_KEY, '') as string;
    } catch (e) {
      console.error('Get background image error:', e);
      return '';
    }
  }

  async setBgImage(uri: string): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(BACKGROUND_IMAGE_KEY, uri);
      await prefs.flush();
    } catch (e) {
      console.error('Set background image error:', e);
    }
  }

  async getBgOpacity(): Promise<number> {
    try {
      const prefs = await this.getPreferences();
      return await prefs.get(BACKGROUND_OPACITY_KEY, 0.15) as number;
    } catch (e) {
      console.error('Get background opacity error:', e);
      return 0.15;
    }
  }

  async setBgOpacity(opacity: number): Promise<void> {
    try {
      const prefs = await this.getPreferences();
      await prefs.put(BACKGROUND_OPACITY_KEY, opacity);
      await prefs.flush();
    } catch (e) {
      console.error('Set background opacity error:', e);
    }
  }
}
