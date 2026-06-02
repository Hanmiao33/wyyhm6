import { ApiService } from '../services/ApiService';
import { PlayerService } from '../services/PlayerService';
import { StorageService } from '../services/StorageService';
import { ThemeManager } from '../services/ThemeManager';
import { thumbnail } from '../utils/ImageUtils';
import { Song, AudioQuality, PlaylistInfo, PlaylistDetail, EffectLevel, PlayerState } from '../models/MusicModel';
import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  hdsMaterial,
  HdsNavigationMenuContentOptions,
  HdsBarStyle,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier, LengthMetrics } from '@kit.ArkUI';
import picker from '@ohos.file.picker';

interface RecommendationSection {
  title: string;
  playlists: PlaylistInfo[];
  songs?: Song[];
}

// 底部页签数据配置
interface TabItem {
  symbolGlyph: SymbolGlyphModifier;
  symbolGlyph1: SymbolGlyphModifier;
  label: string;
}

const TAB_CONFIG: TabItem[] = [
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.house')).fontColor([Color.White]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.house_fill')).fontColor([Color.White]),
    label: '推荐'
  },
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')).fontColor([Color.White]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass')).fontColor([Color.White]),
    label: '搜索'
  },
  {
    symbolGlyph: new SymbolGlyphModifier($r('sys.symbol.person')).fontColor([Color.White]),
    symbolGlyph1: new SymbolGlyphModifier($r('sys.symbol.person_fill')).fontColor([Color.White]),
    label: '我的'
  }
];

@Entry
@Component
struct Index {
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';
  @StorageLink('bgSecondary') bgSecondary: string = '#F5F5F5';
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textSecondary') textSecondary: string = '#000000';
  @StorageLink('textTertiary') textTertiary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('bgImage') bgImage: string = '';
  @StorageLink('bgOpacity') bgOpacity: number = 0.15;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('bottomNavBarHeight') bottomNavBarHeight: number = 0;

  @State sections: RecommendationSection[] = [];
  @State mySections: RecommendationSection[] = [];
  @State isLoading: boolean = false;
  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
  @State currentTabIndex: number = 0;

  // 搜索相关状态
  @State searchKeyword: string = '';
  @State searchResults: Song[] = [];
  @State searchLoading: boolean = false;
  @State currentPage: number = 1;
  @State totalCount: number = 0;
  @State currentPlayingId: number = -1;
  @State searchHistory: string[] = [];
  @State showHistory: boolean = true;

  // 设置 — 效果档位
  @StorageLink('effectLevel') effectLevel: number = EffectLevel.MEDIUM;

  private apiService: ApiService = ApiService.getInstance();
  private playerService: PlayerService = PlayerService.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private tabsController: HdsTabsController = new HdsTabsController();

  // MiniPlayer 状态
  @State miniCurrentSong: Song | null = null;
  @State miniPlayerState: PlayerState = PlayerState.STOPPED;
  @State miniSupportsImmersive: boolean = false;
  @State miniBarExpanded: boolean = false;

  private songListener: ((song: Song | null) => void) | null = null;
  private miniStateListener: ((state: PlayerState) => void) | null = null;

  // 标题栏右侧菜单
  private menus: HdsNavigationMenuContentOptions = {
    value: [
      {
        content: {
          label: '搜索',
          icon: $r('sys.symbol.magnifyingglass'),
          action: (): void => {
            this.tabsController.changeIndex(1);
          }
        }
      },
      {
        content: {
          label: this.isDark ? '浅色' : '深色',
          icon: $r('sys.symbol.moon'),
          action: (): void => {
            this.toggleTheme();
          }
        }
      },
      {
        content: {
          label: '背景',
          icon: $r('sys.symbol.square_grid_2x2'),
          action: (): void => {
            this.pickBgImage();
          }
        }
      }
    ]
  };

  async aboutToAppear() {
    this.storageService.setContext(getContext(this));

    const savedQuality: AudioQuality = await this.storageService.getAudioQuality();
    this.playerService.setQuality(savedQuality);

    // 检测设备沉浸光感能力，选择最优档位
    const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    this.miniSupportsImmersive = materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;

      this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;


    this.songListener = (song: Song | null) => {
      this.miniCurrentSong = song;
      if (song) {
        this.currentPlayingId = song.id;
      }
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.miniCurrentSong = this.playerService.getCurrentSong();
    this.miniPlayerState = this.playerService.getPlayerState();

    this.miniStateListener = (state: PlayerState) => {
      this.miniPlayerState = state;
    };
    this.playerService.addStateChangeListener(this.miniStateListener);

    this.loadRecommendations();
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

  async loadRecommendations() {
    this.isLoading = true;

    const favorites = await this.storageService.getFavorites();
    if (favorites.length > 0) {
      this.mySections = [{ title: '我的收藏', playlists: [], songs: favorites }];
    }

    const playHistory = await this.storageService.getPlayHistory();
    if (playHistory.length > 0) {
      this.mySections = [...this.mySections, { title: '最近播放', playlists: [], songs: playHistory }];
    }

    // 逐个 section 增量渲染，避免一次性加载全部图片
    if (playHistory.length > 0) {
      const historyArtists = this.extractTopArtists(playHistory, 3);
      const historyPlaylists = await this.fetchPlaylistsForArtists(historyArtists, 6);
      if (historyPlaylists.length > 0) {
        this.sections = [...this.sections, { title: '根据播放历史推荐', playlists: historyPlaylists }];
      }
    }

    if (favorites.length > 0) {
      const favArtists = this.extractTopArtists(favorites, 3);
      const favPlaylists = await this.fetchPlaylistsForArtists(favArtists, 6);
      if (favPlaylists.length > 0) {
        this.sections = [...this.sections, { title: '根据收藏推荐', playlists: favPlaylists }];
      }
    }

    try {
      const hotPlaylists = await this.loadHotPlaylists();
      if (hotPlaylists.length > 0) {
        this.sections = [...this.sections, { title: '专辑推荐', playlists: hotPlaylists }];
      }
    } catch (e) {
      console.error('Failed to load hot playlists:', e);
    }

    if (this.sections.length === 0) {
      try {
        const fallback = await this.apiService.getTopPlaylists('全部', 8);
        if (fallback.length > 0) {
          this.sections = [{ title: '专辑推荐', playlists: fallback.slice(0, 8) }];
        }
      } catch (e) {
        console.error('Fallback hot playlists failed:', e);
      }
    }
    this.isLoading = false;
  }

  extractTopArtists(songs: Song[], count: number): string[] {
    const artistCount = new Map<string, number>();
    for (const song of songs) {
      const artists = song.artist.split('/');
      for (const artist of artists) {
        const trimmed = artist.trim();
        if (trimmed && trimmed !== '未知') {
          artistCount.set(trimmed, (artistCount.get(trimmed) || 0) + 1);
        }
      }
    }
    return Array.from(artistCount.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, count)
      .map(e => e[0]);
  }

  async fetchPlaylistsForArtists(artists: string[], limit: number): Promise<PlaylistInfo[]> {
    const seen = new Set<number>();
    const results: PlaylistInfo[] = [];

    for (const artist of artists) {
      if (results.length >= limit) {
        break;
      }
      try {
        const result = await this.apiService.searchPlaylists(artist, 5);
        for (const pl of result.playlists) {
          if (!seen.has(pl.id) && pl.songCount > 0) {
            seen.add(pl.id);
            results.push(pl);
            if (results.length >= limit) {
              break;
            }
          }
        }
      } catch (e) {
        console.error(`Failed to fetch playlists for artist: ${artist}`, e);
      }
    }
    return results;
  }

  async loadHotPlaylists(): Promise<PlaylistInfo[]> {
    try {
      const albums = await this.apiService.getNewAlbums(8);
      if (albums.length > 0) {
        return albums;
      }
    } catch (e) {
      console.error('New albums failed:', e);
    }

    // 兜底：返回内置默认歌单
    return this.getDefaultPlaylists();
  }

  // 内置默认歌单 — 网络不可用时的兜底数据
  private getDefaultPlaylists(): PlaylistInfo[] {
    return [
      {
        id: 3778678,
        name: '热歌榜',
        coverUrl: 'https://p2.music.126.net/DrZIj0dE4EbE0HXwGVnu4A==/109951167163446309.jpg',
        songCount: 100,
        playCount: 0,
        creator: '网易云音乐'
      },
      {
        id: 3779629,
        name: '新歌榜',
        coverUrl: 'https://p1.music.126.net/Gg0HytXxFHWOVQ95DobSOg==/109951167163446023.jpg',
        songCount: 100,
        playCount: 0,
        creator: '网易云音乐'
      },
      {
        id: 2250011884,
        name: '飙升榜',
        coverUrl: 'https://p2.music.126.net/MXQ9ALqZR3rR3QhXHb7bgg==/109951167163445713.jpg',
        songCount: 100,
        playCount: 0,
        creator: '网易云音乐'
      },
      {
        id: 19723756,
        name: '云音乐电音榜',
        coverUrl: 'https://p2.music.126.net/hQ3C6y7TFfIVS0_fBm90Yg==/109951167163445375.jpg',
        songCount: 100,
        playCount: 0,
        creator: '网易云音乐'
      }
    ];
  }

  async openPlaylist(playlist: PlaylistInfo) {
    router.pushUrl({
      url: 'pages/SongListPage',
      params: {
        playlistName: playlist.name,
        playlistId: playlist.id,
        coverUrl: playlist.coverUrl,
        isAlbum: playlist.isAlbum === true,
        artistName: playlist.creator || ''
      }
    });
  }

  async playSongAt(songs: Song[], index: number) {
    this.playerService.setPlaylist(songs, index);
    await this.playerService.playSong(songs[index]);
    router.pushUrl({ url: 'pages/PlayPage' });
  }

  toggleTheme() {
    this.themeManager.toggleTheme();
    this.storageService.setThemeDark(this.themeManager.getIsDark());
  }

  formatPlayCount(count: number): string {
    if (count >= 100000000) {
      return (count / 100000000).toFixed(1) + '亿';
    }
    if (count >= 10000) {
      return (count / 10000).toFixed(1) + '万';
    }
    return count.toString();
  }

  // ========== 搜索功能 ==========
  async searchMusic() {
    if (!this.searchKeyword.trim()) return;

    this.searchLoading = true;
    this.currentPage = 1;
    this.showHistory = false;

    await this.storageService.addSearchHistory(this.searchKeyword);
    this.searchHistory = await this.storageService.getSearchHistory();

    const result = await this.apiService.searchMusic(this.searchKeyword, this.currentPage);
    this.searchResults = result.songs;
    this.totalCount = result.total;
    this.searchLoading = false;
  }

  async loadMore() {
    if (this.searchLoading || this.searchResults.length >= this.totalCount) return;

    this.searchLoading = true;
    this.currentPage++;

    const result = await this.apiService.searchMusic(this.searchKeyword, this.currentPage);
    this.searchResults = [...this.searchResults, ...result.songs];
    this.searchLoading = false;
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

  async setEffectLevel(level: EffectLevel) {
    this.effectLevel = level;
    await this.storageService.setEffectLevel(level);
  }

  // ========== 背景图片 ==========
  async pickBgImage() {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new picker.PhotoViewPicker();
      const result = await photoViewPicker.select(photoSelectOptions);
      if (result.photoUris.length > 0) {
        AppStorage.setOrCreate<string>('bgImage', result.photoUris[0]);
        await this.storageService.setBgImage(result.photoUris[0]);
        promptAction.showToast({ message: '背景图片已更换', duration: 1500 });
      }
    } catch (e) {
      console.error('Pick background image error:', e);
      promptAction.showToast({ message: '选择图片失败', duration: 1500 });
    }
  }

  async clearBgImage() {
    AppStorage.setOrCreate<string>('bgImage', '');
    await this.storageService.setBgImage('');
    promptAction.showToast({ message: '已恢复默认背景', duration: 1500 });
  }

  async setBgOpacity(opacity: number) {
    AppStorage.setOrCreate<number>('bgOpacity', opacity);
    await this.storageService.setBgOpacity(opacity);
  }

  // ========== MiniPlayer 辅助方法 ==========
  getMiniBlurScale(): number {
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

  getMiniOverlayOpacity(): number {
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

  @Builder
  MiniBarBuilder() {
    if (this.miniCurrentSong) {
      if (this.miniBarExpanded) {
        // 展开态：完整布局（封面 + 歌名 + 播放控制）
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

          Button() {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(18)
              .fontColor([this.textTertiary])
          }
          .width(36)
          .height(36)
          .backgroundColor('transparent')
          .margin({ left: 2 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/PlayPage' });
          })
        }
        .width('100%')
        .height(64)
        .padding({ left: 16, right: 8 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
      } else {
        // 折叠态：居中显示封面
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

  // ========== Builders ==========
  @Builder
  PlaylistCard(playlist: PlaylistInfo) {
    Column() {
      // 封面：缩略图
      Image(thumbnail(playlist.coverUrl, 300, 300))
        .width(150)
        .height(150)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)

      Text(playlist.name)
        .fontSize(13)
        .fontColor(this.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })
      Row() {
        if (playlist.isAlbum) {
          Text(playlist.creator || '')
            .fontSize(11)
            .fontColor(this.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        } else {
          Text(`${playlist.songCount}首`)
            .fontSize(11)
            .fontColor(this.textTertiary)
          if (playlist.playCount > 0) {
            Text(` · ${this.formatPlayCount(playlist.playCount)}`)
              .fontSize(11)
              .fontColor(this.textTertiary)
          }
        }
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .width(150)
    .margin({ right: 12 })
    .onClick(() => {
      this.openPlaylist(playlist);
    })
  }

  // 根据歌单名生成占位色
  getPlaceholderColor(name: string): string {
    const colors: string[] = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
      '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
      '#BB8FCE', '#85C1E9', '#F0B27A', '#82E0AA'
    ];
    let hash: number = 0;
    for (let i = 0; i < name.length; i++) {
      hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    return colors[Math.abs(hash) % colors.length];
  }

  @Builder
  SongCard(song: Song, songs: Song[] | undefined, index: number) {
    Column() {
      // 封面：缩略图
      Image(thumbnail(song.coverUrl, 300, 300))
        .width(140)
        .height(140)
        .borderRadius(8)
        .objectFit(ImageFit.Cover)
      Text(song.name)
        .fontSize(13)
        .fontColor(this.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })
      Text(`${song.artist}`)
        .fontSize(11)
        .fontColor(this.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })
    }
    .width(140)
    .margin({ right: 12 })
    .onClick(() => {
      if (songs) {
        this.playSongAt(songs, index);
      }
    })
  }

  @Builder
  SectionBlock(section: RecommendationSection) {
    Column() {
      Row() {
        Text(section.title)
          .fontSize(18)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 24, bottom: 12 })

      List() {
        if (section.songs && section.songs.length > 0) {
          ForEach(section.songs, (song: Song, index: number) => {
            ListItem() {
              this.SongCard(song, section.songs, index)
            }
          })
        } else {
          ForEach(section.playlists, (playlist: PlaylistInfo) => {
            ListItem() {
              this.PlaylistCard(playlist)
            }
          })
        }
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height(220)
      .padding({ left: 16, right: 16 })
    }
  }

  // ========== 推荐 Tab 内容 ==========
  @Builder
  RecommendTab() {
    Column() {
      Row() {}.height(70).width('100%')
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载推荐中...')
            .fontSize(14)
            .fontColor(this.textTertiary)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.sections, (section: RecommendationSection) => {
            ListItem() {
              this.SectionBlock(section)
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
        .cachedCount(0)
      }
    }
    .width('100%')
    .height('100%')
  }

  // ========== 搜索 Tab 内容 ==========
  @Builder
  SearchTab() {
    Column() {
      Row() {}.height(100).width('100%')
      // 搜索框
      Row() {
        TextInput({ placeholder: '搜索歌曲、歌手、专辑', text: this.searchKeyword })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.bgSecondary)
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
                Row() {
                  Image(thumbnail(song.coverUrl, 100, 100))
                    .width(48)
                    .height(48)
                    .borderRadius(6)
                    .objectFit(ImageFit.Cover)
                    .margin({ right: 12 })

                  Column() {
                    Text(song.name)
                      .fontSize(15)
                      .fontColor(song.id === this.currentPlayingId ? this.accent : this.textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(`${song.artist} · ${song.album}`)
                      .fontSize(12)
                      .fontColor(this.textTertiary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .onClick(() => {
                  this.playSong(song, index);
                })
              }
            })

            if (this.searchLoading) {
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
        } else if (!this.showHistory && !this.searchLoading) {
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
      .backgroundColor(this.bgPrimary)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgPrimary)
  }

  // ========== 我的 Tab 内容 ==========
  @Builder
  MyProfileTab() {
    Column() {
      Row() {}.height(70).width('100%')
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor(this.textTertiary)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 用户信息头部
            Row() {
              SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
                .fontSize(64)
                .fontColor([this.textSecondary])

              Column() {
                Text('我的音乐')
                  .fontSize(22)
                  .fontColor(this.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Text('收藏与播放记录')
                  .fontSize(13)
                  .fontColor(this.textTertiary)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 16 })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 8 })
            .alignItems(VerticalAlign.Center)

            // 我的收藏、最近播放板块
            ForEach(this.mySections, (section: RecommendationSection) => {
              this.SectionBlock(section)
            })

            // 背景设置板块
            Column() {
              Row() {
                Text('背景设置')
                  .fontSize(18)
                  .fontColor(this.textPrimary)
                  .fontWeight(FontWeight.Bold)
                Blank()
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 32, bottom: 12 })

              // 当前背景预览
              if (this.bgImage) {
                Stack() {
                  Image(this.bgImage)
                    .width('100%')
                    .height(120)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(12)
                  Row()
                    .width('100%')
                    .height('100%')
                    .backgroundColor(this.isDark ? '#000000' : '#FFFFFF')
                    .opacity(this.bgOpacity)
                }
                .width('100%')
                .padding({ left: 16, right: 16 })
                .margin({ bottom: 12 })
              }

              Button('📷  选择背景图片')
                .width('100%')
                .height(44)
                .backgroundColor(this.accent)
                .borderRadius(22)
                .fontColor('#FFFFFF')
                .fontSize(15)
                .margin({ left: 16, right: 16 })
                .onClick(() => {
                  this.pickBgImage();
                })

              if (this.bgImage) {
                Row() {
                  Text('透明度')
                    .fontSize(14)
                    .fontColor(this.textSecondary)
                  Slider({
                    value: this.bgOpacity * 100,
                    min: 5,
                    max: 60,
                    step: 5
                  })
                    .layoutWeight(1)
                    .margin({ left: 12 })
                    .onChange((value: number) => {
                      this.setBgOpacity(value / 100);
                    })
                  Text(`${Math.round(this.bgOpacity * 100)}%`)
                    .fontSize(13)
                    .fontColor(this.textSecondary)
                    .width(40)
                    .textAlign(TextAlign.End)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 16 })

                Button('恢复默认')
                  .width('100%')
                  .height(40)
                  .backgroundColor('transparent')
                  .borderRadius(20)
                  .fontColor(this.accent)
                  .fontSize(14)
                  .margin({ left: 16, right: 16, top: 8 })
                  .onClick(() => {
                    this.clearBgImage();
                  })
              }
            }
            .width('100%')
            .margin({ top: 8 })

            // 底部留白：浮动页签
            Blank()
              .height(64)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      // 背景图片层（在 HdsNavigation 下方）
      if (this.bgImage) {
        Image(this.bgImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
        // 半透明遮罩（保持内容可读性）
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.isDark ? '#000000' : '#FFFFFF')
          .opacity(this.bgOpacity)
      }

      HdsNavigation() {
        HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            this.RecommendTab()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[0].symbolGlyph,
            selected: TAB_CONFIG[0].symbolGlyph1
          }, TAB_CONFIG[0].label))

          TabContent() {
            this.SearchTab()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[1].symbolGlyph,
            selected: TAB_CONFIG[1].symbolGlyph1
          }, TAB_CONFIG[1].label))

          TabContent() {
            this.MyProfileTab()
          }
          .tabBar(new BottomTabBarStyle({
            normal: TAB_CONFIG[2].symbolGlyph,
            selected: TAB_CONFIG[2].symbolGlyph1
          }, TAB_CONFIG[2].label))
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
        .onChange((index: number) => {
          this.currentTabIndex = index;
        })
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        content: {
          title: { mainTitle: '音乐' },
          menu: this.menus
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
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .height('100%')
  }
}
