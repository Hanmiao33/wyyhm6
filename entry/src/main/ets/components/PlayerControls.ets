import { PlayerService } from '../services/PlayerService';
import { PlayMode, PlayerState, Song } from '../models/MusicModel';

@Component
export struct PlayerControls {
  @StorageLink('textSecondary') textSecondary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('isDark') isDark: boolean = false;

  playlistAction: () => void = () => {};

  @State currentState: PlayerState = PlayerState.STOPPED;
  @State currentSong: Song | null = null;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State playMode: PlayMode = PlayMode.SEQUENCE;

  private playerService: PlayerService = PlayerService.getInstance();

  private stateListener: ((state: PlayerState) => void) | null = null;
  private songListener: ((song: Song | null) => void) | null = null;
  private progressListener: ((position: number, duration: number) => void) | null = null;

  aboutToAppear() {
    this.currentState = this.playerService.getPlayerState();
    this.currentSong = this.playerService.getCurrentSong();
    this.currentPosition = this.playerService.getCurrentPosition();
    this.duration = this.playerService.getDuration();
    this.playMode = this.playerService.getPlayMode();

    this.stateListener = (state: PlayerState) => {
      this.currentState = state;
    };
    this.playerService.addStateChangeListener(this.stateListener);

    this.songListener = (song: Song | null) => {
      this.currentSong = song;
    };
    this.playerService.addSongChangeListener(this.songListener);

    this.progressListener = (position: number, duration: number) => {
      this.currentPosition = position;
      this.duration = duration;
    };
    this.playerService.addProgressChangeListener(this.progressListener);
  }

  aboutToDisappear() {
    if (this.stateListener) {
      this.playerService.removeStateChangeListener(this.stateListener);
    }
    if (this.songListener) {
      this.playerService.removeSongChangeListener(this.songListener);
    }
    if (this.progressListener) {
      this.playerService.removeProgressChangeListener(this.progressListener);
    }
  }

  build() {
    Column() {
      // 进度条
      Row() {
        Text(this.formatTime(this.currentPosition))
          .fontSize(12)
          .fontColor(this.textSecondary)

        Slider({
          value: this.currentPosition,
          min: 0,
          max: this.duration,
          step: 1
        })
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })
          .onChange((value: number) => {
            this.playerService.seekTo(value);
          })

        Text(this.formatTime(this.duration))
          .fontSize(12)
          .fontColor(this.textSecondary)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 控制按钮行 — 全部使用简约矢量图标
      Row() {
        // 播放模式
        Button() {
          if (this.playMode === PlayMode.SEQUENCE) {
            SymbolGlyph($r('sys.symbol.list_bullet'))
              .fontSize(22)
              .fontColor([this.textSecondary])
          } else if (this.playMode === PlayMode.LOOP) {
            SymbolGlyph($r('sys.symbol.repeat'))
              .fontSize(22)
              .fontColor([this.accent])
          } else if (this.playMode === PlayMode.SINGLE) {
            SymbolGlyph($r('sys.symbol.repeat_1'))
              .fontSize(22)
              .fontColor([this.accent])
          } else if (this.playMode === PlayMode.RANDOM) {
            SymbolGlyph($r('sys.symbol.shuffle'))
              .fontSize(22)
              .fontColor([this.textSecondary])
          }
        }
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .onClick(() => {
            this.togglePlayMode();
          })

        // 上一曲
        Button() {
          this.PrevIcon()
        }
          .width(50)
          .height(50)
          .backgroundColor('transparent')
          .onClick(() => {
            this.playerService.playPrevious();
          })

        // 播放/暂停 — 大圆按钮
        Button() {
          if (this.currentState === PlayerState.PLAYING) {
            this.PauseIcon('#FFFFFF')
          } else {
            this.PlayIcon('#FFFFFF')
          }
        }
          .width(60)
          .height(60)
          .borderRadius(30)
          .backgroundColor(this.accent)
          .onClick(() => {
            if (this.currentState === PlayerState.PLAYING) {
              this.playerService.pause();
            } else {
              this.playerService.play();
            }
          })

        // 下一曲
        Button() {
          this.NextIcon()
        }
          .width(50)
          .height(50)
          .backgroundColor('transparent')
          .onClick(() => {
            this.playerService.playNext();
          })

        // 播放列表
        Button() {
          this.ListIcon()
        }
          .width(40)
          .height(40)
          .backgroundColor('transparent')
          .onClick(() => {
            this.playlistAction();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .padding({ top: 8, bottom: 8 })
    }
  }

  // ========== 系统 Symbol 图标 ==========

  @Builder
  PlayIcon(color: ResourceColor) {
    SymbolGlyph($r('sys.symbol.play_fill'))
      .fontSize(34)
      .fontColor([color])
  }

  @Builder
  PauseIcon(color: ResourceColor) {
    SymbolGlyph($r('sys.symbol.pause_fill'))
      .fontSize(34)
      .fontColor([color])
  }

  @Builder
  PrevIcon() {
    SymbolGlyph($r('sys.symbol.backward_fill'))
      .fontSize(26)
      .fontColor([this.textSecondary])
  }

  @Builder
  NextIcon() {
    SymbolGlyph($r('sys.symbol.forward_end_fill'))
      .fontSize(26)
      .fontColor([this.textSecondary])
  }

  @Builder
  PlayModeIcon(mode: PlayMode) {
    if (mode === PlayMode.SEQUENCE) {
      SymbolGlyph($r('sys.symbol.list_bullet'))
        .fontSize(22)
        .fontColor([this.textSecondary])
    } else if (mode === PlayMode.LOOP) {
      SymbolGlyph($r('sys.symbol.repeat'))
        .fontSize(22)
        .fontColor([this.accent])
    } else if (mode === PlayMode.SINGLE) {
      SymbolGlyph($r('sys.symbol.repeat_1'))
        .fontSize(22)
        .fontColor([this.accent])
    } else if (mode === PlayMode.RANDOM) {
      SymbolGlyph($r('sys.symbol.shuffle'))
        .fontSize(22)
        .fontColor([this.textSecondary])
    }
  }

  @Builder
  ListIcon() {
    SymbolGlyph($r('sys.symbol.list_bullet'))
      .fontSize(22)
      .fontColor([this.textSecondary])
  }

  formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  togglePlayMode() {
    const modes = [PlayMode.SEQUENCE, PlayMode.LOOP, PlayMode.RANDOM, PlayMode.SINGLE];
    const currentIndex = modes.indexOf(this.playMode);
    this.playMode = modes[(currentIndex + 1) % modes.length];
    this.playerService.setPlayMode(this.playMode);
  }
}
