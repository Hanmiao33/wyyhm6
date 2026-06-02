import { PlayerService } from '../services/PlayerService';
import { thumbnail } from '../utils/ImageUtils';
import { Song, PlayerState, EffectLevel } from '../models/MusicModel';
import { hdsMaterial } from '@kit.UIDesignKit';
import router from '@ohos.router';

@Component
export struct MiniPlayer {
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textTertiary') textTertiary: string = '#000000';
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';
  @StorageLink('effectLevel') effectLevel: number = EffectLevel.MEDIUM;

  @State currentSong: Song | null = null;
  @State playerState: PlayerState = PlayerState.STOPPED;
  @State supportsImmersive: boolean = false;

  private playerService: PlayerService = PlayerService.getInstance();

  private songListener: ((song: Song | null) => void) | null = null;
  private stateListener: ((state: PlayerState) => void) | null = null;

  aboutToAppear() {
    this.currentSong = this.playerService.getCurrentSong();
    this.playerState = this.playerService.getPlayerState();

    // 检测设备沉浸光感能力
    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    this.supportsImmersive = materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;

    this.songListener = (song: Song | null) => {
      this.currentSong = song;
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.stateListener = (state: PlayerState) => {
      this.playerState = state;
    };
    this.playerService.addStateChangeListener(this.stateListener);
  }

  aboutToDisappear() {
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.stateListener) {
      this.playerService.removeStateChangeListener(this.stateListener);
    }
  }

  getBlurScale(): number {
    if (!this.supportsImmersive) {
      return 0.3;
    }
    switch (this.effectLevel) {
      case EffectLevel.OFF:
        return 0;
      case EffectLevel.LOW:
        return 0.3;
      case EffectLevel.MEDIUM:
        return 0.6;
      case EffectLevel.HIGH:
        return 1.0;
      default:
        return 0.6;
    }
  }

  getOverlayOpacity(): number {
    if (!this.supportsImmersive) {
      return 0.12;
    }
    switch (this.effectLevel) {
      case EffectLevel.OFF:
        return 0;
      case EffectLevel.LOW:
        return 0.12;
      case EffectLevel.MEDIUM:
        return 0.25;
      case EffectLevel.HIGH:
        return 0.4;
      default:
        return 0.25;
    }
  }

  build() {
    Column() {
      if (this.currentSong) {
        // 浮动胶囊容器
        Stack() {
          // 背景模糊层
          Row()
            .width('100%')
            .height('100%')
            .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
              scale: this.getBlurScale()
            })

          // 半透底色
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor('#FFFFFF')
            .opacity(this.getOverlayOpacity())

          // 内容层
          Row() {
            Image(thumbnail(this.currentSong.coverUrl, 100, 100))
              .width(44)
              .height(44)
              .borderRadius(10)
              .objectFit(ImageFit.Cover)

            Column() {
              Text(this.currentSong.name || '未知歌曲')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(this.currentSong.artist || '未知歌手')
                .fontSize(12)
                .fontColor(this.textTertiary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .margin({ left: 12 })
            .alignItems(HorizontalAlign.Start)

            Button() {
              Text(this.playerState === PlayerState.PLAYING ? '⏸' : '▶')
                .fontSize(20)
                .fontColor(this.textPrimary)
            }
            .width(44)
            .height(44)
            .backgroundColor('transparent')
            .onClick(() => {
              if (this.playerState === PlayerState.PLAYING) {
                this.playerService.pause();
              } else {
                this.playerService.play();
              }
            })

            Button() {
              Text('⏭')
                .fontSize(18)
                .fontColor(this.textPrimary)
            }
            .width(44)
            .height(44)
            .backgroundColor('transparent')
            .onClick(() => {
              this.playerService.playNext();
            })
          }
          .width('100%')
          .height(64)
          .padding({ left: 16, right: 8 })
        }
        .width('100%')
        .height(64)
        .onClick(() => {
          router.pushUrl({ url: 'pages/PlayPage' });
        })
      }
    }
    .width('calc(100% - 24vp)')
    .margin({ left: 12, right: 12, bottom: 12 })
    .borderRadius(24)
    .shadow({ radius: 20, color: '#1A000000', offsetX: 0, offsetY: 6 })
    .backgroundColor(this.bgPrimary)
    .clip(true)
  }
}
