/**
 * 通用 LRU 内存缓存（类型安全版）
 * ArkTS 不支持开放泛型 as T 转换，使用 JSON 序列化实现类型擦除
 */
export class CacheService {
  private static instance: CacheService;
  private cache: Map<string, string> = new Map(); // key → JSON
  private expiry: Map<string, number> = new Map(); // key → expireAt
  private order: string[] = []; // LRU 顺序，尾部最新
  private readonly maxSize: number = 200;

  private constructor() {}

  public static getInstance(): CacheService {
    if (!CacheService.instance) {
      CacheService.instance = new CacheService();
    }
    return CacheService.instance;
  }

  /**
   * 写入缓存
   */
  set(key: string, data: Object, ttlMs: number = 5 * 60 * 1000): void {
    // 超出容量时淘汰最早的条目
    if (this.cache.size >= this.maxSize) {
      const oldest: string | undefined = this.order.shift();
      if (oldest !== undefined) {
        this.cache.delete(oldest);
        this.expiry.delete(oldest);
      }
    }
    this.cache.set(key, JSON.stringify(data));
    this.expiry.set(key, Date.now() + ttlMs);
    // 更新 LRU 顺序
    const idx: number = this.order.indexOf(key);
    if (idx >= 0) {
      this.order.splice(idx, 1);
    }
    this.order.push(key);
  }

  /**
   * 读取缓存（返回 JSON 字符串，调用方自行 parse）
   * 过期自动删除
   */
  get(key: string): string | null {
    const expireAt: number | undefined = this.expiry.get(key);
    if (expireAt === undefined) {
      return null;
    }
    if (Date.now() > expireAt) {
      this.delete(key);
      return null;
    }
    const json: string | undefined = this.cache.get(key);
    if (json === undefined) {
      return null;
    }
    // LRU：移到末尾
    const idx: number = this.order.indexOf(key);
    if (idx >= 0) {
      this.order.splice(idx, 1);
    }
    this.order.push(key);
    return json;
  }

  /**
   * 检查缓存是否存在且未过期
   */
  has(key: string): boolean {
    return this.get(key) !== null;
  }

  /**
   * 删除指定键
   */
  delete(key: string): void {
    this.cache.delete(key);
    this.expiry.delete(key);
    const idx: number = this.order.indexOf(key);
    if (idx >= 0) {
      this.order.splice(idx, 1);
    }
  }

  /**
   * 按前缀批量清除
   */
  clearByPrefix(prefix: string): void {
    const keysToDelete: string[] = [];
    // 遍历所有键，收集匹配前缀的
    const allKeys: string[] = this.order.slice();
    for (let i = 0; i < allKeys.length; i++) {
      if (allKeys[i].startsWith(prefix)) {
        keysToDelete.push(allKeys[i]);
      }
    }
    for (let i = 0; i < keysToDelete.length; i++) {
      this.delete(keysToDelete[i]);
    }
  }

  /**
   * 清空全部缓存
   */
  clear(): void {
    this.cache.clear();
    this.expiry.clear();
    this.order = [];
  }

  /**
   * 当前缓存条目数
   */
  get size(): number {
    return this.cache.size;
  }
}
