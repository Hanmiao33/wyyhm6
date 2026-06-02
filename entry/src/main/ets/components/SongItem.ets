import { thumbnail } from '../utils/ImageUtils';
import { Song } from '../models/MusicModel';

@Component
export struct SongItem {
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textTertiary') textTertiary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('accentLight') accentLight: string = '#FFF5F5';
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';

  @Prop song: Song;
  @Prop index: number;
  @Prop isActive: boolean = false;
  onItemClick: (song: Song, index: number) => void = () => {};

  build() {
    Row() {
      // 封面图片：缩略图 80x80
      Image(thumbnail(this.song.coverUrl, 80, 80))
        .width(40)
        .height(40)
        .borderRadius(6)
        .objectFit(ImageFit.Cover)
        .backgroundColor(this.isActive ? this.accentLight : this.bgPrimary)

      Column() {
        Text(this.song.name)
          .fontSize(15)
          .fontColor(this.isActive ? this.accent : this.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .fontWeight(this.isActive ? FontWeight.Medium : FontWeight.Medium)

        Text(`${this.song.artist} - ${this.song.album}`)
          .fontSize(12)
          .fontColor(this.textTertiary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Text(this.formatDuration(this.song.duration))
        .fontSize(12)
        .fontColor(this.textTertiary)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.isActive ? this.accentLight : this.bgPrimary)
    .onClick(() => {
      this.onItemClick(this.song, this.index);
    })
  }

  formatDuration(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }
}
