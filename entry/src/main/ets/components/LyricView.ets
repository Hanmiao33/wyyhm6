import { LyricLine, Song } from '../models/MusicModel';
import { PlayerService } from '../services/PlayerService';

@Component
export struct LyricView {
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('isDark') isDark: boolean = false;
  @StorageLink('bgSecondary') bgSecondary: string = '#F5F5F5';

  @State lyrics: LyricLine[] = [];
  @State currentIndex: number = -1;

  private playerService: PlayerService = PlayerService.getInstance();
  private scroller: Scroller = new Scroller();

  private lyricListener: ((index: number, text: string) => void) | null = null;
  private songListener: ((song: Song | null) => void) | null = null;

  aboutToAppear() {
    this.loadLyrics();

    this.lyricListener = (index: number, text: string) => {
      this.currentIndex = index;
      if (index >= 0) {
        this.scrollToCurrentLyric();
      }
    };
    this.playerService.addLyricChangeListener(this.lyricListener);

    this.songListener = (song: Song | null) => {
      if (song) {
        setTimeout(() => {
          this.loadLyrics();
        }, 500);
      }
    };
    this.playerService.addSongChangeListener(this.songListener);
  }

  aboutToDisappear() {
    if (this.lyricListener) {
      this.playerService.removeLyricChangeListener(this.lyricListener);
    }
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
  }

  loadLyrics() {
    const allLyrics = this.playerService.getLyrics();
    if (allLyrics && allLyrics.length > 0) {
      this.lyrics = allLyrics;
    }
    this.currentIndex = this.playerService.getCurrentLyricIndex();
  }

  scrollToCurrentLyric() {
    if (this.currentIndex >= 0) {
      this.scroller.scrollToIndex(this.currentIndex);
    }
  }

  build() {
    Column() {
      if (this.lyrics.length > 0) {
        List({ scroller: this.scroller }) {
          // 顶部留白，让当前歌词居中
          ListItem() {
            Row().width('100%').height(120)
          }

          ForEach(this.lyrics, (lyric: LyricLine, index: number) => {
            ListItem() {
              Text(lyric.text)
                .fontSize(index === this.currentIndex ? 18 : 15)
                .fontColor(index === this.currentIndex ? this.accent :
                  (this.isDark ? '#CCCCCC' : '#000000'))
                .fontWeight(index === this.currentIndex ? FontWeight.Bold : FontWeight.Medium)
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .animation({ duration: 300, curve: Curve.EaseOut })
            }
          })

          // 底部留白
          ListItem() {
            Row().width('100%').height(120)
          }
        }
        .width('100%')
        .height('100%')
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Off)
      } else {
        // 无歌词时的占位提示
        Column() {
          // 微光唱片图标（简化矢量）
          Shape() {
            Path()
              .commands('M 12 4 A 8 8 0 1 1 12 20 A 8 8 0 1 1 12 4 Z ' +
                'M 12 7 A 5 5 0 1 1 12 17 A 5 5 0 1 1 12 7 Z')
              .strokeWidth(1.5)
              .stroke(this.isDark ? '#666666' : '#000000')
              .fillOpacity(0)
          }
          .width(48)
          .height(48)

          Text('暂无歌词')
            .fontSize(15)
            .fontColor(this.isDark ? '#666666' : '#000000')
            .margin({ top: 16 })

          Text('静静聆听音乐的美好')
            .fontSize(13)
            .fontColor(this.isDark ? '#444444' : '#BBBBBB')
            .margin({ top: 6 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
  }
}
