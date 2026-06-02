import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * 封面图本地缓存服务
 * 将网络图片下载到应用缓存目录，避免重复下载和解码
 * 最大缓存 100 张图片，超出时淘汰最早使用的
 */
export class ImageCacheService {
  private static instance: ImageCacheService;
  private context: Context | null = null;
  private memoryIndex: Map<string, string> = new Map(); // url → localPath
  private pendingDownloads: Map<string, Promise<string>> = new Map(); // 防止同一 URL 重复下载
  private initialized: boolean = false;
  private readonly maxCacheFiles: number = 100;
  private readonly cacheSubDir: string = 'cover_cache';

  private constructor() {}

  public static getInstance(): ImageCacheService {
    if (!ImageCacheService.instance) {
      ImageCacheService.instance = new ImageCacheService();
    }
    return ImageCacheService.instance;
  }

  /**
   * 初始化，需在 Ability onCreate 中调用
   */
  async init(context: Context): Promise<void> {
    this.context = context;
    const cacheDir = this.getCacheDir();
    try {
      if (!fs.accessSync(cacheDir)) {
        fs.mkdirSync(cacheDir);
      }
    } catch (e) {
      // 目录已存在，忽略
    }
    await this.rebuildIndex();
    this.initialized = true;
  }

  private getCacheDir(): string {
    if (!this.context) {
      return '';
    }
    return `${this.context.cacheDir}/${this.cacheSubDir}`;
  }

  /**
   * 从 URL 生成文件名（MD5 hash）
   */
  private urlToFileName(url: string): string {
    // 简单哈希：用 charCode 累积，避免引入重依赖
    let hash = 0;
    for (let i = 0; i < url.length; i++) {
      const ch = url.charCodeAt(i);
      hash = ((hash << 5) - hash) + ch;
      hash = hash & hash; // 转 32 位整数
    }
    // 提取 URL 中的扩展名，默认 .jpg
    let ext = '.jpg';
    const dotIndex = url.lastIndexOf('.');
    const slashIndex = url.lastIndexOf('/');
    if (dotIndex > slashIndex && dotIndex > 0) {
      const candidate = url.substring(dotIndex, dotIndex + 5).split('?')[0];
      if (candidate.length <= 5) {
        ext = candidate;
      }
    }
    return `img_${Math.abs(hash).toString(16)}${ext}`;
  }

  /**
   * 启动时扫描缓存目录，重建内存索引
   */
  private async rebuildIndex(): Promise<void> {
    const cacheDir = this.getCacheDir();
    try {
      const files = fs.listFileSync(cacheDir);
      for (const file of files) {
        const fullPath = `${cacheDir}/${file}`;
        this.memoryIndex.set(file, fullPath);
      }
    } catch (e) {
      console.error('ImageCacheService rebuildIndex error:', e);
    }
  }

  /**
   * 获取缓存图片的本地路径
   * 如果已缓存返回本地路径，否则下载后返回
   * @param url 网络图片 URL
   * @returns 本地文件路径（可直接传给 Image 组件）
   */
  async getCachedPath(url: string): Promise<string> {
    if (!url || !this.initialized) {
      return url;
    }

    const fileName = this.urlToFileName(url);
    const localPath = `${this.getCacheDir()}/${fileName}`;

    // 1. 内存索引命中
    if (this.memoryIndex.has(fileName)) {
      try {
        if (fs.accessSync(localPath)) {
          // 更新文件访问时间（LRU 依据）
          fs.openSync(localPath, fs.OpenMode.READ_ONLY);
          return localPath;
        }
      } catch (e) {
        // 文件已被系统清理，继续下载
        this.memoryIndex.delete(fileName);
      }
    }

    // 2. 防止同一 URL 并发重复下载
    const existing = this.pendingDownloads.get(url);
    if (existing) {
      return existing;
    }

    // 3. 下载并缓存
    const downloadPromise = this.downloadAndCache(url, localPath, fileName);
    this.pendingDownloads.set(url, downloadPromise);

    try {
      const result = await downloadPromise;
      return result;
    } finally {
      this.pendingDownloads.delete(url);
    }
  }

  private async downloadAndCache(url: string, localPath: string, fileName: string): Promise<string> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://music.163.com',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      httpRequest.destroy();

      if (response.responseCode === 200) {
        // 写入本地文件
        const file = fs.openSync(localPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.writeSync(file.fd, response.result as ArrayBuffer);
        fs.closeSync(file);

        this.memoryIndex.set(fileName, localPath);

        // 超出容量时淘汰
        await this.evictIfNeeded();

        return localPath;
      }
    } catch (e) {
      console.error('ImageCacheService download error:', url, e);
    }

    // 下载失败时返回原始 URL，让 Image 组件自己尝试
    return url;
  }

  /**
   * 缓存文件超出上限时淘汰最早的
   */
  private async evictIfNeeded(): Promise<void> {
    if (this.memoryIndex.size <= this.maxCacheFiles) {
      return;
    }

    const excess: number = this.memoryIndex.size - this.maxCacheFiles;
    const keysToDelete: string[] = [];
    // 将 Map 的键转为数组，避免使用 MapIterator
    const allKeys: string[] = Array.from(this.memoryIndex.keys());
    for (let i = 0; i < excess && i < allKeys.length; i++) {
      keysToDelete.push(allKeys[i]);
    }
    for (let i = 0; i < keysToDelete.length; i++) {
      const path: string | undefined = this.memoryIndex.get(keysToDelete[i]);
      if (path) {
        try {
          fs.unlinkSync(path);
        } catch (e) {
          // ignore
        }
      }
      this.memoryIndex.delete(keysToDelete[i]);
    }
  }

  /**
   * 清空全部图片缓存
   */
  async clearAll(): Promise<void> {
    const cacheDir = this.getCacheDir();
    try {
      const files = fs.listFileSync(cacheDir);
      for (const file of files) {
        try {
          fs.unlinkSync(`${cacheDir}/${file}`);
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      console.error('ImageCacheService clearAll error:', e);
    }
    this.memoryIndex.clear();
  }

  /**
   * 缓存文件数量
   */
  get cacheSize(): number {
    return this.memoryIndex.size;
  }
}
