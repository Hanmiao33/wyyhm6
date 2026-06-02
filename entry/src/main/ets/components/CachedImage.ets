import { ImageCacheService } from '../services/ImageCacheService';

/**
 * 带本地缓存的 Image 组件
 * 先用原 URL 立即显示，缓存就绪后切换到本地路径
 */
@Component
struct CachedImage {
  @Prop src: string = '';
  @State displayPath: string = '';

  private imageCacheService: ImageCacheService = ImageCacheService.getInstance();

  imgWidth: Length = '100%';
  imgHeight: Length = '100%';
  imgObjectFit: ImageFit = ImageFit.Cover;
  imgBorderRadius: Length = 0;
  imgBackgroundColor: ResourceColor = '#F0F0F0';

  aboutToAppear(): void {
    if (!this.src) {
      return;
    }
    // 立即用原 URL 显示，不阻塞渲染
    this.displayPath = this.src;
    // 后台获取缓存路径，就绪后替换
    this.imageCacheService.getCachedPath(this.src).then((cached: string) => {
      if (cached && cached !== this.src) {
        this.displayPath = cached;
      }
    });
  }

  build() {
    if (this.displayPath) {
      Image(this.displayPath)
        .width(this.imgWidth)
        .height(this.imgHeight)
        .objectFit(this.imgObjectFit)
        .borderRadius(this.imgBorderRadius)
        .backgroundColor(this.imgBackgroundColor)
    } else {
      Row()
        .width(this.imgWidth)
        .height(this.imgHeight)
        .borderRadius(this.imgBorderRadius)
        .backgroundColor(this.imgBackgroundColor)
    }
  }
}

export { CachedImage }
