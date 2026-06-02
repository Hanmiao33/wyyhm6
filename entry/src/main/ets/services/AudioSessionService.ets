import { avSession } from '@kit.AVSessionKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, common } from '@kit.AbilityKit';
import type { WantAgent } from '@ohos.wantAgent';
import http from '@ohos.net.http';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import { Song, PlayerState } from '../models/MusicModel';

const TAG: string = 'AudioSessionService';

/**
 * 媒体控制回调接口
 */
export interface MediaCallbacks {
  onPlay: () => void;
  onPause: () => void;
  onNext: () => void;
  onPrevious: () => void;
  onSeek: (position: number) => void;
}

export class AudioSessionService {
  private static instance: AudioSessionService;
  private context: common.UIAbilityContext | null = null;
  private session: avSession.AVSession | null = null;
  private isBackgroundTaskRunning: boolean = false;
  private lastProgressUpdateTime: number = 0;
  private wantAgentInstance: WantAgent | null = null;

  // 封面缓存
  private cachedCoverUrl: string = '';
  private cachedCoverPixelMap: image.PixelMap | null = null;

  // 媒体控制回调（由 PlayerService 注册）
  private onPlayCallback: (() => void) | null = null;
  private onPauseCallback: (() => void) | null = null;
  private onNextCallback: (() => void) | null = null;
  private onPreviousCallback: (() => void) | null = null;
  private onSeekCallback: ((position: number) => void) | null = null;

  private constructor() {}

  public static getInstance(): AudioSessionService {
    if (!AudioSessionService.instance) {
      AudioSessionService.instance = new AudioSessionService();
    }
    return AudioSessionService.instance;
  }

  /**
   * 注册媒体控制回调
   */
  setMediaCallbacks(callbacks: MediaCallbacks): void {
    this.onPlayCallback = callbacks.onPlay;
    this.onPauseCallback = callbacks.onPause;
    this.onNextCallback = callbacks.onNext;
    this.onPreviousCallback = callbacks.onPrevious;
    this.onSeekCallback = callbacks.onSeek;
  }

  /**
   * 初始化：创建 WantAgent 和 AVSession
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      await this.createWantAgent();
      await this.createAVSession();
      console.info(TAG, 'AudioSessionService initialized');
    } catch (err) {
      console.error(TAG, 'Failed to init AudioSessionService:', JSON.stringify(err));
    }
  }

  /**
   * 创建 WantAgent，用于通知栏点击回到应用
   */
  private async createWantAgent(): Promise<void> {
    if (!this.context) {
      return;
    }

    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: this.context.applicationInfo.name,
            abilityName: 'EntryAbility',
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
      };
      this.wantAgentInstance = await wantAgent.getWantAgent(wantAgentInfo);
      console.info(TAG, 'WantAgent created');
    } catch (err) {
      console.error(TAG, 'Failed to create WantAgent:', JSON.stringify(err));
    }
  }

  private async createAVSession(): Promise<void> {
    if (!this.context) {
      return;
    }

    // 创建 AVSession
    this.session = await avSession.createAVSession(this.context, 'MusicPlayer', 'audio');
    console.info(TAG, 'AVSession created');

    // 注册媒体控制回调
    this.session.on('play', (): void => {
      console.info(TAG, 'AVSession play event');
      if (this.onPlayCallback) {
        this.onPlayCallback();
      }
    });

    this.session.on('pause', (): void => {
      console.info(TAG, 'AVSession pause event');
      if (this.onPauseCallback) {
        this.onPauseCallback();
      }
    });

    this.session.on('playNext', (): void => {
      console.info(TAG, 'AVSession playNext event');
      if (this.onNextCallback) {
        this.onNextCallback();
      }
    });

    this.session.on('playPrevious', (): void => {
      console.info(TAG, 'AVSession playPrevious event');
      if (this.onPreviousCallback) {
        this.onPreviousCallback();
      }
    });

    this.session.on('seek', (position: number): void => {
      console.info(TAG, 'AVSession seek event:', position);
      if (this.onSeekCallback) {
        this.onSeekCallback(position / 1000); // AVSession 传入的是毫秒，转换为秒
      }
    });

    // 激活会话
    await this.session.activate();
    console.info(TAG, 'AVSession activated');
  }

  /**
   * 启动后台长时任务
   */
  async startBackgroundTask(): Promise<void> {
    if (!this.context || this.isBackgroundTaskRunning) {
      return;
    }

    if (!this.wantAgentInstance) {
      console.error(TAG, 'WantAgent not initialized, cannot start background task');
      return;
    }

    try {
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        this.wantAgentInstance
      );
      this.isBackgroundTaskRunning = true;
      console.info(TAG, 'Background task started');
    } catch (err) {
      console.error(TAG, 'Failed to start background task:', JSON.stringify(err));
    }
  }

  /**
   * 停止后台长时任务
   */
  async stopBackgroundTask(): Promise<void> {
    if (!this.context || !this.isBackgroundTaskRunning) {
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isBackgroundTaskRunning = false;
      console.info(TAG, 'Background task stopped');
    } catch (err) {
      console.error(TAG, 'Failed to stop background task:', JSON.stringify(err));
    }
  }

  /**
   * 下载网络图片并转换为 PixelMap
   */
  private async fetchCoverPixelMap(coverUrl: string): Promise<image.PixelMap | null> {
    if (!coverUrl) {
      console.error(TAG, 'Cover URL is empty');
      return null;
    }

    // 使用缓存
    if (coverUrl === this.cachedCoverUrl && this.cachedCoverPixelMap) {
      console.info(TAG, 'Using cached cover PixelMap');
      return this.cachedCoverPixelMap;
    }

    // 去掉 ?param= 缩略图参数，使用原图
    const originalUrl: string = coverUrl.split('?')[0];
    const tempPath: string = (this.context?.cacheDir || '') + '/cover_temp.jpg';

    try {
      console.info(TAG, 'Downloading cover from:', originalUrl);
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(originalUrl, {
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 15000,
        header: {
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        }
      });

      if (response.responseCode !== http.ResponseCode.OK || !response.result) {
        console.error(TAG, 'Failed to download cover, status:', response.responseCode);
        httpRequest.destroy();
        return null;
      }

      const imageData: ArrayBuffer = response.result as ArrayBuffer;
      httpRequest.destroy();
      console.info(TAG, 'Cover downloaded, size:', imageData.byteLength);

      // 写入临时文件
      const file = fs.openSync(tempPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(file.fd, imageData);
      fs.closeSync(file);

      // 从文件创建 ImageSource（使用 file:// URI）
      const imageSource: image.ImageSource = image.createImageSource('file://' + tempPath);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap();
      imageSource.release();

      // 清理临时文件
      try {
        fs.unlinkSync(tempPath);
      } catch (e) {
        // 忽略
      }

      // 更新缓存
      this.cachedCoverUrl = coverUrl;
      if (this.cachedCoverPixelMap) {
        this.cachedCoverPixelMap.release();
      }
      this.cachedCoverPixelMap = pixelMap;

      console.info(TAG, 'Cover PixelMap created successfully');
      return pixelMap;
    } catch (err) {
      console.error(TAG, 'Failed to fetch cover PixelMap:', JSON.stringify(err));
      try {
        fs.unlinkSync(tempPath);
      } catch (e) {
        // 忽略
      }
      return null;
    }
  }

  /**
   * 更新歌曲元数据（含封面）
   */
  async updateMetadata(song: Song): Promise<void> {
    if (!this.session) {
      return;
    }

    try {
      // 获取封面 PixelMap
      const coverPixelMap: image.PixelMap | null = await this.fetchCoverPixelMap(song.coverUrl);

      const metadata: avSession.AVMetadata = {
        assetId: song.id.toString(),
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration,
      };

      if (coverPixelMap) {
        metadata.mediaImage = coverPixelMap;
      }

      await this.session.setAVMetadata(metadata);
      console.info(TAG, 'Metadata updated:', song.name, coverPixelMap ? 'with cover' : 'no cover');
    } catch (err) {
      console.error(TAG, 'Failed to update metadata:', JSON.stringify(err));
    }
  }

  /**
   * 将 PlayerState 映射为 AVSession 播放状态
   */
  private mapPlayerState(state: PlayerState): avSession.PlaybackState {
    switch (state) {
      case PlayerState.PLAYING:
        return avSession.PlaybackState.PLAYBACK_STATE_PLAY;
      case PlayerState.PAUSED:
        return avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
      case PlayerState.LOADING:
        return avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
      default:
        return avSession.PlaybackState.PLAYBACK_STATE_STOP;
    }
  }

  /**
   * 更新播放状态
   */
  async updatePlaybackState(state: PlayerState, position: number, duration: number): Promise<void> {
    if (!this.session) {
      return;
    }

    // 根据播放状态决定是否启停后台任务
    if (state === PlayerState.PLAYING) {
      await this.startBackgroundTask();
    } else if (state === PlayerState.STOPPED) {
      await this.stopBackgroundTask();
    }

    try {
      const playbackState: avSession.AVPlaybackState = {
        state: this.mapPlayerState(state),
        position: {
          elapsedTime: position * 1000,
          updateTime: Date.now(),
        },
        speed: 1.0,
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (err) {
      console.error(TAG, 'Failed to update playback state:', JSON.stringify(err));
    }
  }

  /**
   * 更新播放进度（带节流，每秒最多更新一次）
   */
  async updateProgress(position: number, duration: number): Promise<void> {
    if (!this.session) {
      return;
    }

    const now: number = Date.now();
    if (now - this.lastProgressUpdateTime < 1000) {
      return;
    }
    this.lastProgressUpdateTime = now;

    try {
      const playbackState: avSession.AVPlaybackState = {
        state: avSession.PlaybackState.PLAYBACK_STATE_PLAY,
        position: {
          elapsedTime: position * 1000,
          updateTime: now,
        },
        speed: 1.0,
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (err) {
      // 进度更新失败静默处理，避免刷屏
    }
  }

  /**
   * 销毁服务
   */
  async destroy(): Promise<void> {
    await this.stopBackgroundTask();

    // 释放封面缓存
    if (this.cachedCoverPixelMap) {
      this.cachedCoverPixelMap.release();
      this.cachedCoverPixelMap = null;
      this.cachedCoverUrl = '';
    }

    if (this.session) {
      try {
        await this.session.deactivate();
        await this.session.destroy();
        this.session = null;
        console.info(TAG, 'AVSession destroyed');
      } catch (err) {
        console.error(TAG, 'Failed to destroy AVSession:', JSON.stringify(err));
      }
    }

    this.wantAgentInstance = null;
    this.context = null;
  }
}
