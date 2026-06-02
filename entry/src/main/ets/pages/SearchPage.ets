import { ApiService } from '../services/ApiService';
import { PlayerService } from '../services/PlayerService';
import { StorageService } from '../services/StorageService';
import { ThemeManager } from '../services/ThemeManager';
import { thumbnail } from '../utils/ImageUtils';
import { Song, PlayerState, EffectLevel } from '../models/MusicModel';
import { SongItem } from '../components/SongItem';
import router from '@ohos.router';
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
struct SearchPage {
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';
  @StorageLink('bgSecondary') bgSecondary: string = '#F5F5F5';
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textTertiary') textTertiary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('bgImage') bgImage: string = '';
  @StorageLink('bgOpacity') bgOpacity: number = 0.15;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageLink('effectLevel') effectLevel: number = EffectLevel.MEDIUM;

  @State searchKeyword: string = '';
  @State searchResults: Song[] = [];
  @State isLoading: boolean = false;
  @State currentPage: number = 1;
  @State totalCount: number = 0;
  @State currentPlayingId: number = -1;
  @State searchHistory: string[] = [];
  @State showHistory: boolean = true;

  // MiniPlayer 状态
  @State miniCurrentSong: Song | null = null;
  @State miniPlayerState: PlayerState = PlayerState.STOPPED;
  @State miniSupportsImmersive: boolean = false;
  @State miniBarExpanded: boolean = false;

  private apiService: ApiService = ApiService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private tabsController: HdsTabsController = new HdsTabsController();
  private customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  private songListener: ((song: Song | null) => void) | null = null;
  private miniStateListener: ((state: PlayerState) => void) | null = null;

  async aboutToAppear() {
    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    this.miniSupportsImmersive = materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
    this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;

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

    this.searchHistory = await this.storageService.getSearchHistory();
  }

  aboutToDisappear() {
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.miniStateListener) {
      this.playerService.removeStateChangeListener(this.miniStateListener);
    }
  }

  async searchMusic() {
    if (!this.searchKeyword.trim()) return;

    this.isLoading = true;
    this.currentPage = 1;
    this.showHistory = false;

    await this.storageService.addSearchHistory(this.searchKeyword);
    this.searchHistory = await this.storageService.getSearchHistory();

    const result = await this.apiService.searchMusic(this.searchKeyword, this.currentPage);
    this.searchResults = result.songs;
    this.totalCount = result.total;
    this.isLoading = false;
  }

  async loadMore() {
    if (this.isLoading || this.searchResults.length >= this.totalCount) return;

    this.isLoading = true;
    this.currentPage++;

    const result = await this.apiService.searchMusic(this.searchKeyword, this.currentPage);
    this.searchResults = [...this.searchResults, ...result.songs];
    this.isLoading = false;
  }

  async playSong(song: Song, index: number) {
    this.playerService.setPlaylist(this.searchResults, index);
    await this.storageService.addPlayHistory(song);
    await this.playerService.playSong(song);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  async clearSearchHistory() {
    await this.storageService.clearSearchHistory();
    this.searchHistory = [];
  }

  selectHistory(keyword: string) {
    this.searchKeyword = keyword;
    this.searchMusic();
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
            Column() {
              Row() {}.height(70).width('100%')

              // 搜索框（沉浸光感）
              Row() {
                TextInput({ placeholder: '搜索歌曲、歌手、专辑', text: this.searchKeyword })
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor(Color.Transparent)
                  .borderRadius(20)
                  .padding({ left: 16, right: 16 })
                  .fontColor(this.textPrimary)
                  .placeholderColor(this.textTertiary)
                  .onChange((value: string) => {
                    this.searchKeyword = value;
                    if (value === '') {
                      this.showHistory = true;
                      this.searchResults = [];
                    }
                  })
                  .onSubmit(() => {
                    this.searchMusic();
                  })

                Button('搜索')
                  .height(40)
                  .margin({ left: 12 })
                  .backgroundColor(this.accent)
                  .borderRadius(20)
                  .onClick(() => {
                    this.searchMusic();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              // 内容区域
              Column() {
                if (this.showHistory && this.searchHistory.length > 0 && this.searchResults.length === 0) {
                  Row() {
                    Text('搜索历史')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.textPrimary)
                    Blank()
                    Button('清空')
                      .fontSize(12)
                      .height(28)
                      .backgroundColor('transparent')
                      .fontColor(this.textTertiary)
                      .onClick(() => {
                        this.clearSearchHistory();
                      })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 16, bottom: 12 })

                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(this.searchHistory, (keyword: string) => {
                      Button(keyword)
                        .fontSize(13)
                        .height(32)
                        .backgroundColor(this.bgSecondary)
                        .borderRadius(16)
                        .fontColor(this.textPrimary)
                        .margin({ right: 8, bottom: 8 })
                        .onClick(() => {
                          this.selectHistory(keyword);
                        })
                    })
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16 })
                }

                if (this.searchResults.length > 0) {
                  Row() {
                    Text(`找到 ${this.totalCount} 首歌曲`)
                      .fontSize(14)
                      .fontColor(this.textTertiary)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 8 })

                  List() {
                    ForEach(this.searchResults, (song: Song, index: number) => {
                      ListItem() {
                        SongItem({
                          song: song,
                          index: index,
                          isActive: song.id === this.currentPlayingId,
                          onItemClick: (s: Song, i: number) => {
                            this.playSong(s, i);
                          }
                        })
                      }
                    })

                    if (this.isLoading) {
                      ListItem() {
                        Row() {
                          LoadingProgress()
                            .width(24)
                            .height(24)
                          Text('加载中...')
                            .fontSize(14)
                            .fontColor(this.textTertiary)
                            .margin({ left: 8 })
                        }
                        .width('100%')
                        .height(50)
                        .justifyContent(FlexAlign.Center)
                      }
                    } else if (this.searchResults.length < this.totalCount) {
                      ListItem() {
                        Text('加载更多')
                          .fontSize(14)
                          .fontColor(this.accent)
                          .width('100%')
                          .height(50)
                          .textAlign(TextAlign.Center)
                          .onClick(() => {
                            this.loadMore();
                          })
                      }
                    }
                  }
                  .layoutWeight(1)
                  .width('100%')
                } else if (!this.isLoading && this.searchHistory.length === 0) {
                  Column() {
                    Text('暂无搜索结果')
                      .fontSize(14)
                      .fontColor(this.textTertiary)
                  }
                  .width('100%')
                  .layoutWeight(1)
                  .justifyContent(FlexAlign.Center)
                }
              }
              .layoutWeight(1)
              .width('100%')
            }
            .width('100%')
            .height('100%')
          }
          .tabBar(new BottomTabBarStyle({
            normal: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')).fontColor([Color.White]),
            selected: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')).fontColor([Color.White])
          }, '搜索'))
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
          title: { mainTitle: '搜索' }
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
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
  }
}
