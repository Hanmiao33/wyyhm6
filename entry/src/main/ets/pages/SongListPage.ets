import { ApiService } from '../services/ApiService';
import { PlayerService } from '../services/PlayerService';
import { thumbnail } from '../utils/ImageUtils';
import { Song, PlaylistDetail, PlayerState, EffectLevel } from '../models/MusicModel';
import { SongItem } from '../components/SongItem';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  hdsMaterial,
  HdsBarStyle,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier, LengthMetrics } from '@kit.ArkUI';

@Entry
@Component
struct SongListPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';
  @StorageLink('bgSecondary') bgSecondary: string = '#F5F5F5';
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textTertiary') textTertiary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('accentLight') accentLight: string = '#FFF0F0';
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('bgImage') bgImage: string = '';
  @StorageLink('bgOpacity') bgOpacity: number = 0.15;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageLink('effectLevel') effectLevel: number = EffectLevel.MEDIUM;

  @State playlistName: string = '';
  @State playlistId: number = 0;
  @State coverUrl: string = '';
  @State isAlbum: boolean = false;
  @State artistName: string = '';
  @State songs: Song[] = [];
  @State isLoading: boolean = true;
  @State currentPlayingId: number = -1;

  // MiniPlayer 状态
  @State miniCurrentSong: Song | null = null;
  @State miniPlayerState: PlayerState = PlayerState.STOPPED;
  @State miniSupportsImmersive: boolean = false;
  @State miniBarExpanded: boolean = false;

  private apiService: ApiService = ApiService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();
  private tabsController: HdsTabsController = new HdsTabsController();
  private customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  private songListener: ((song: Song | null) => void) | null = null;
  private miniStateListener: ((state: PlayerState) => void) | null = null;

  async aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.playlistName = params['playlistName'] as string || '';
      this.playlistId = params['playlistId'] as number || 0;
      this.coverUrl = params['coverUrl'] as string || '';
      this.isAlbum = params['isAlbum'] === true;
      this.artistName = params['artistName'] as string || '';
    }

    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    this.miniSupportsImmersive = materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
    this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;

    // MiniPlayer 监听
    this.miniCurrentSong = this.playerService.getCurrentSong();
    this.miniPlayerState = this.playerService.getPlayerState();
    if (this.miniCurrentSong) {
      this.currentPlayingId = this.miniCurrentSong.id;
    }

    this.songListener = (song: Song | null) => {
      this.miniCurrentSong = song;
      if (song) {
        this.currentPlayingId = song.id;
      }
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.miniStateListener = (state: PlayerState) => {
      this.miniPlayerState = state;
    };
    this.playerService.addStateChangeListener(this.miniStateListener);

    await this.loadPlaylistDetail();
  }

  aboutToDisappear() {
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.miniStateListener) {
      this.playerService.removeStateChangeListener(this.miniStateListener);
    }
  }

  async loadPlaylistDetail() {
    this.isLoading = true;
    try {
      let detail: PlaylistDetail | null = null;
      if (this.isAlbum) {
        detail = await this.apiService.getAlbumDetail(this.playlistId, this.playlistName, this.artistName, this.coverUrl);
      } else {
        detail = await this.apiService.getPlaylistDetail(this.playlistId);
      }
      if (detail && detail.songs.length > 0) {
        this.songs = detail.songs;
        // 用接口返回的封面和名称更新
        if (detail.info.coverUrl) {
          this.coverUrl = detail.info.coverUrl;
        }
        if (detail.info.name) {
          this.playlistName = detail.info.name;
        }
      } else {
        promptAction.showToast({ message: '暂时无法加载，请重试', duration: 2000 });
      }
    } catch (e) {
      console.error('Load detail error:', e);
      promptAction.showToast({ message: '网络异常，请检查网络后重试', duration: 2000 });
    }
    this.isLoading = false;
  }

  playSong(song: Song, index: number) {
    this.playerService.setPlaylist(this.songs, index);
    this.playerService.playSong(song);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  // ========== 沉浸光感效果 ==========
  getBlurScale(): number {
    if (!this.miniSupportsImmersive) {
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
    if (!this.miniSupportsImmersive) {
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

  // ========== MiniBarBuilder ==========
  @Builder
  MiniBarBuilder() {
    if (this.miniCurrentSong) {
      if (this.miniBarExpanded) {
        Row() {
          Image(thumbnail(this.miniCurrentSong.coverUrl, 100, 100))
            .width(50)
            .height(50)
            .borderRadius(25)
            .objectFit(ImageFit.Cover)

          Column() {
            Text(this.miniCurrentSong.name || '未知歌曲')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.textPrimary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.miniCurrentSong.artist || '未知歌手')
              .fontSize(12)
              .fontColor(this.textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .margin({ left: 16 })
          .alignItems(HorizontalAlign.Start)

          Button() {
            if (this.miniPlayerState === PlayerState.PLAYING) {
              SymbolGlyph($r('sys.symbol.pause_fill'))
                .fontSize(20)
                .fontColor([this.textPrimary])
            } else {
              SymbolGlyph($r('sys.symbol.play_fill'))
                .fontSize(20)
                .fontColor([this.textPrimary])
            }
          }
          .width(44)
          .height(44)
          .backgroundColor('transparent')
          .onClick(() => {
            if (this.miniPlayerState === PlayerState.PLAYING) {
              this.playerService.pause();
            } else {
              this.playerService.play();
            }
          })

          Button() {
            SymbolGlyph($r('sys.symbol.forward_end_fill'))
              .fontSize(18)
              .fontColor([this.textPrimary])
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
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
      } else {
        Row() {
          Image(thumbnail(this.miniCurrentSong.coverUrl, 100, 100))
            .width(50)
            .height(50)
            .borderRadius(25)
            .objectFit(ImageFit.Cover)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
    }
  }

  build() {
    Stack() {
      // 背景图片层
      if (this.bgImage) {
        Image(this.bgImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.isDark ? '#000000' : '#FFFFFF')
          .opacity(this.bgOpacity)
      }

      HdsNavigation() {
        HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            // 歌曲列表内容
            Column() {
              if (this.isLoading) {
                Column() {
                  LoadingProgress()
                    .width(40)
                    .height(40)
                  Text('加载歌曲列表中...')
                    .fontSize(14)
                    .fontColor(this.textTertiary)
                    .margin({ top: 12 })
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
              } else if (this.songs.length === 0) {
                Column() {
                  Text('该歌单暂无歌曲')
                    .fontSize(14)
                    .fontColor(this.textTertiary)
                }
                .width('100%')
                .layoutWeight(1)
                .justifyContent(FlexAlign.Center)
              } else {
                // 歌曲列表（沉浸光感效果）
                Stack() {
                  // 背景模糊层
                  Row()
                    .width('100%')
                    .height('100%')
                    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
                      scale: this.getBlurScale()
                    })

                  // 半透明底色
                  Row()
                    .width('100%')
                    .height('100%')
                    .backgroundColor(this.isDark ? '#000000' : '#FFFFFF')
                    .opacity(this.getOverlayOpacity())

                  // 列表内容
                  Column() {
                    Column()
                      .height(200)
                    List() {
                      ForEach(this.songs, (song: Song, index: number) => {
                        ListItem() {
                          SongItem({
                            song: song,
                            index: index,
                            isActive: song.id === this.currentPlayingId,
                            onItemClick: (clickedSong: Song, clickedIndex: number) => {
                              this.playSong(clickedSong, clickedIndex);
                            }
                          })
                        }
                      })
                      ListItem() {
                        Column() {
                          Blank().height(64)
                        }
                      }
                    }
                    .width('100%')
                    .layoutWeight(1)
                    .scrollBar(BarState.Off)
                    .edgeEffect(EdgeEffect.Spring)
                  }
                  .width('100%')
                  .height('100%')
                }
                .width('100%')
                .layoutWeight(1)
              }
            }
            .width('100%')
            .height('100%')
          }
          .tabBar(new BottomTabBarStyle({
            normal: new SymbolGlyphModifier($r('sys.symbol.list_bullet')).fontColor([Color.White]),
            selected: new SymbolGlyphModifier($r('sys.symbol.list_bullet')).fontColor([Color.White])
          }, '歌单'))
        }
        .barOverlap(true)
        .vertical(false)
        .barPosition(BarPosition.End)
        .scrollable(false)
        .animationDuration(0)
        .layoutWeight(1)
        .barFloatingStyle({
          barBottomMargin: 24,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: this.customMaterialLevel
          },
          miniBar: {
            miniBarBuilder: (): void => this.MiniBarBuilder(),
            onBarStyleChange: (miniBarStyle: HdsBarStyle) => {
              this.miniBarExpanded = miniBarStyle === HdsBarStyle.EXPAND;
            }
          }
        })
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: { mainTitle: this.playlistName }
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
    }
    .width('100%')
    .height('100%')
  }
}
