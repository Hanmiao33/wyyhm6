import { PlayerService } from '../services/PlayerService';
import { StorageService } from '../services/StorageService';
import { thumbnail } from '../utils/ImageUtils';
import { Song, PlayerState, AudioQuality, SongQualityInfo } from '../models/MusicModel';
import { PlayerControls } from '../components/PlayerControls';
import { LyricView } from '../components/LyricView';
import router from '@ohos.router';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  HdsNavigationMenuContentOptions,
  IconStyleMode,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

@Entry
@Component
struct PlayPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';
  @StorageLink('bgSecondary') bgSecondary: string = '#F5F5F5';
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textSecondary') textSecondary: string = '#000000';
  @StorageLink('textTertiary') textTertiary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('accentLight') accentLight: string = '#FFF0F0';
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('border') themeBorder: string = '#F5F5F5';
  @StorageLink('overlay') themeOverlay: string = '#00000060';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State currentSong: Song | null = null;
  @State playerState: PlayerState = PlayerState.STOPPED;
  @State coverRotation: number = 0;
  @State isFavorite: boolean = false;
  @State currentQuality: AudioQuality = AudioQuality.EXHIGH;
  @State showQualityDialog: boolean = false;
  @State showPlaylist: boolean = false;
  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
  @State swiperIndex: number = 0;

  private playerService: PlayerService = PlayerService.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private timer: number = 0;
  private swiperController: SwiperController = new SwiperController();

  private songListener: ((song: Song | null) => void) | null = null;
  private stateListener: ((state: PlayerState) => void) | null = null;

  async aboutToAppear() {
    this.currentSong = this.playerService.getCurrentSong();
    this.playerState = this.playerService.getPlayerState();
    this.currentQuality = this.playerService.getQuality();

    // 检测设备沉浸光感能力，选择最优档位
    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    } else {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
    }

    if (this.currentSong) {
      this.isFavorite = await this.storageService.isFavorite(this.currentSong.id);
    }

    this.songListener = async (song: Song | null) => {
      this.currentSong = song;
      if (song) {
        this.isFavorite = await this.storageService.isFavorite(song.id);
      }
      if (song && this.playerState !== PlayerState.PLAYING && this.playerState !== PlayerState.LOADING) {
        this.playerService.playSong(song);
      }
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.stateListener = (state: PlayerState) => {
      this.playerState = state;
      if (state === PlayerState.PLAYING) {
        this.startRotation();
      } else {
        this.stopRotation();
      }
    };
    this.playerService.addStateChangeListener(this.stateListener);

    const playlist = this.playerService.getPlaylist();
    const currentIndex = this.playerService.getCurrentIndex();
    if (playlist.length > 0 && currentIndex >= 0 && currentIndex < playlist.length) {
      const currentSong: Song | null = this.playerService.getCurrentSong();
      if (this.playerState === PlayerState.STOPPED && (!currentSong || !currentSong.url)) {
        await this.playerService.playSong(playlist[currentIndex]);
      }
    }
  }

  aboutToDisappear() {
    this.stopRotation();
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.stateListener) {
      this.playerService.removeStateChangeListener(this.stateListener);
    }
  }

  startRotation() {
    this.timer = setInterval(() => {
      this.coverRotation = (this.coverRotation + 1) % 360;
    }, 50);
  }

  stopRotation() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = 0;
    }
  }

  async toggleFavorite() {
    if (!this.currentSong) return;
    this.isFavorite = await this.storageService.toggleFavorite(this.currentSong);
  }

  build() {
    Stack() {
      // === 背景层：当前歌曲封面取色模糊 ===
      if (this.currentSong?.coverUrl) {
        Image(thumbnail(this.currentSong.coverUrl, 500, 500))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(50)
          .scale({ x: 1.2, y: 1.2 }) // 放大避免边缘透出底色

        // 半透明遮罩，保证前景文字可读
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.isDark ? '#000000' : '#FFFFFF')
          .opacity(this.isDark ? 0.5 : 0.3)
      }

      // === 主内容 ===
      HdsNavigation() {
        Column() {
          // Swiper：封面页 ↔ 歌词页（右滑）
          Swiper(this.swiperController) {
            // ---- 页面 0：封面 + 歌曲信息 ----
            Column() {
              // 封面（旋转 CD）
              Image(thumbnail(this.currentSong?.coverUrl || '', 300, 300))
                .width(250)
                .height(250)
                .borderRadius(125)
                .border({ width: 6, color: this.isDark ? '#FFFFFF20' : '#FFFFFF' })
                .rotate({ angle: this.coverRotation })
                .objectFit(ImageFit.Cover)
                .shadow({ radius: 20, color: '#00000030' })

              // 歌曲信息
              Column() {
                Text(this.currentSong?.name || '未知歌曲')
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.textPrimary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 24 })

                Text(this.currentSong?.artist || '未知歌手')
                  .fontSize(16)
                  .fontColor(this.textSecondary)
                  .margin({ top: 8 })

                Text(this.currentSong?.album || '未知专辑')
                  .fontSize(14)
                  .fontColor(this.textTertiary)
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .height('100%')
            .padding({ top: 20 })
            .margin({ top: this.statusBarHeight + 48 })
            .justifyContent(FlexAlign.Start)
            .alignItems(HorizontalAlign.Center)

            // ---- 页面 1：全屏歌词（右滑显示） ----
            LyricView()
              .width('100%')
              .height('100%')
              .margin({ top: this.statusBarHeight + 48 + 20 })
          }
          .width('100%')
          .layoutWeight(1)    // 填满剩余空间，不挤压 PlayerControls
          .loop(false)
          .indicator(false)
          .index(this.swiperIndex)
          .onChange((index: number) => {
            this.swiperIndex = index;
          })

          // 播放控件（始终在底部）
          PlayerControls({
            playlistAction: (): void => {
              this.showPlaylist = true;
            }
          })
            .margin({ bottom: 48 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#00000000') // 透明让背景层透出
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: {
            mainTitle: this.swiperIndex === 0 ? '正在播放' : '歌词'
          },
          menu: {
            value: [
              {
                content: {
                  label: this.getQualityLabel(this.currentQuality),
                  icon: $r('sys.symbol.speaker_wave_2'),
                  type: IconStyleMode.NORMAL,
                  action: (): void => {
                    this.showQualityDialog = true;
                  }
                }
              },
              {
                content: {
                  label: this.isFavorite ? '已收藏' : '收藏',
                  icon: this.isFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'),
                  type: IconStyleMode.NORMAL,
                  action: (): void => {
                    this.toggleFavorite();
                  }
                }
              }
            ]
          }
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(40)
          },
          blurStrategy: BlurStrategy.ADAPTIVE,
          originalStyle: { backgroundStyle: { backgroundColor: '#00FFFFFF' } },
          scrollEffectStyle: { backgroundStyle: { backgroundColor: '#00FFFFFF' } },
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.customMaterialLevel
          }
        }
      })
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(false)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])

      if (this.showQualityDialog) {
        this.QualityDialog()
      }

      if (this.showPlaylist) {
        this.PlaylistDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder QualityDialog() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeOverlay)
        .onClick(() => {
          this.showQualityDialog = false;
        })

      Column() {
        Text('选择音质')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textPrimary)
          .margin({ top: 20, bottom: 16 })

        ForEach(this.getQualityOptions(), (item: QualityOption) => {
          Row() {
            Column() {
              Text(item.label)
                .fontSize(16)
                .fontColor(this.currentQuality === item.quality ? this.accent : this.textPrimary)
                .fontWeight(this.currentQuality === item.quality ? FontWeight.Bold : FontWeight.Medium)

              Text(item.desc)
                .fontSize(12)
                .fontColor(this.textTertiary)
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            if (this.currentQuality === item.quality) {
              Text('✓')
                .fontSize(18)
                .fontColor(this.accent)
                .fontWeight(FontWeight.Bold)
            }
          }
          .width('100%')
          .height(56)
          .padding({ left: 20, right: 20 })
          .onClick(() => {
            this.changeQuality(item.quality);
          })
        })

        Row()
          .width('100%')
          .height(20)
      }
      .width('100%')
      .backgroundColor(this.bgPrimary)
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder PlaylistDialog() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeOverlay)
        .onClick(() => {
          this.showPlaylist = false;
        })

      Column() {
        // 标题栏（沉浸模糊）
        Row() {
          Text('播放列表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textPrimary)
          Blank()
          Text(`${this.playerService.getPlaylist().length} 首`)
            .fontSize(14)
            .fontColor(this.textTertiary)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 12 })
        .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
          scale: 0.6
        })

        // 歌曲列表
        List({ space: 0 }) {
          ForEach(this.playerService.getPlaylist(), (item: Song, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.name)
                    .fontSize(15)
                    .fontColor(item.id === this.currentSong?.id ? this.accent : this.textPrimary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.artist || '未知')
                    .fontSize(12)
                    .fontColor(this.textTertiary)
                    .margin({ top: 2 })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (item.id === this.currentSong?.id) {
                  // 正在播放指示器
                  Shape() {
                    Path()
                      .commands('M 12 4 A 8 8 0 1 1 12 20 A 8 8 0 1 1 12 4 Z')
                      .fill(this.accent)
                  }
                  .width(16)
                  .height(16)
                  .margin({ left: 8 })
                }
              }
              .width('100%')
              .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              .onClick(() => {
                this.showPlaylist = false;
                this.playerService.playSong(item);
              })
            }
          })
        }
        .width('100%')
        .height('50%')
        .backgroundColor(this.bgSecondary)
        .borderRadius({ topLeft: 12, topRight: 12 })

        Row()
          .width('100%')
          .height(20)
      }
      .width('100%')
      .borderRadius({ topLeft: 16, topRight: 16 })
      .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
        scale: 0.6
      })
      .backgroundColor(this.isDark ? '#1A1A1AE0' : '#FFFFFFE0')
    }
    .width('100%')
    .height('100%')
  }

  getQualityOptions(): QualityOption[] {
    const available: SongQualityInfo[] = this.playerService.getAvailableQualities();
    const allOptions: QualityOption[] = [
      { quality: AudioQuality.STANDARD, label: '标准', desc: '128kbps · 流畅播放' },
      { quality: AudioQuality.HIGHER, label: '较高', desc: '192kbps · 均衡之选' },
      { quality: AudioQuality.EXHIGH, label: '极高', desc: '320kbps · 高品质' },
      { quality: AudioQuality.LOSSLESS, label: '无损', desc: 'FLAC · 极致音质' },
    ];

    const availableLevels: Set<number> = new Set();
    for (const q of available) {
      availableLevels.add(q.level);
    }

    const result: QualityOption[] = [];
    for (const opt of allOptions) {
      const isAvailable: boolean = availableLevels.has(opt.quality);
      const qualityInfo: SongQualityInfo | undefined = available.find(
        (q: SongQualityInfo) => q.level === opt.quality
      );
      const sizeStr: string = qualityInfo && qualityInfo.size > 0
        ? ` · ${this.formatSize(qualityInfo.size)}`
        : '';
      const desc: string = isAvailable ? opt.desc + sizeStr : opt.desc + ' · 不可用';
      result.push({ quality: opt.quality, label: opt.label, desc: desc });
    }
    return result;
  }

  changeQuality(quality: AudioQuality) {
    this.currentQuality = quality;
    this.playerService.setQuality(quality);
    this.storageService.setAudioQuality(quality);
    this.showQualityDialog = false;
  }

  getQualityLabel(quality: AudioQuality): string {
    switch (quality) {
      case AudioQuality.STANDARD:
        return '标准';
      case AudioQuality.HIGHER:
        return '较高';
      case AudioQuality.EXHIGH:
        return '极高';
      case AudioQuality.LOSSLESS:
        return '无损';
      default:
        return '极高';
    }
  }

  formatSize(bytes: number): string {
    if (bytes <= 0) return '';
    const mb: number = bytes / 1024 / 1024;
    return mb.toFixed(1) + 'MB';
  }
}

interface QualityOption {
  quality: AudioQuality;
  label: string;
  desc: string;
}
