import { EffectLevel } from '../models/MusicModel';
import { StorageService } from '../services/StorageService';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  hdsMaterial,
  ScrollEffectType,
  BlurStrategy
} from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

@Component
struct EffectLevelOption {
  @StorageLink('textPrimary') textPrimary: string = '#000000';
  @StorageLink('textSecondary') textSecondary: string = '#000000';
  @StorageLink('accent') accent: string = '#FF6B6B';
  @StorageLink('bgPrimary') bgPrimary: string = '#FFFFFF';
  @StorageLink('effectLevel') globalLevel: number = EffectLevel.MEDIUM;

  @Prop level: EffectLevel;
  @Prop label: string;
  @Prop desc: string;

  private storageService: StorageService = StorageService.getInstance();

  build() {
    Row() {
      Column() {
        Text(this.label)
          .fontSize(16)
          .fontColor(this.globalLevel === this.level ? this.accent : this.textPrimary)
          .fontWeight(this.globalLevel === this.level ? FontWeight.Bold : FontWeight.Medium)
        Text(this.desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.globalLevel === this.level) {
        Text('✓')
          .fontSize(18)
          .fontColor(this.accent)
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.globalLevel === this.level ? this.bgPrimary : Color.Transparent)
    .borderRadius(12)
    .onClick(async () => {
      this.globalLevel = this.level;
      await this.storageService.setEffectLevel(this.level);
    })
  }
}

@Entry
@Component
struct SettingsPage {
  @StorageLink('bgSecondary') bgSecondary: string = '#F5F5F5';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  @State customMaterialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;

  aboutToAppear(): void {
    const materialTypes: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.includes(hdsMaterial.MaterialType.IMMERSIVE)) {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
    } else {
      this.customMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
    }
  }

  build() {
    HdsNavigation() {
      Column() {
        // 沉浸光感说明
        Row() {
          Text('沉浸光感效果会在底部迷你播放器和列表封面区域展示动态光晕效果，' +
          '根据播放歌曲的色调实时变化。')
            .fontSize(13)
            .fontColor('#000000')
            .lineHeight(20)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })

        // 效果档位选项
        Column() {
          EffectLevelOption({
            level: EffectLevel.OFF,
            label: '关闭',
            desc: '无光感效果，纯净界面'
          })

          Divider()
            .strokeWidth(0.5)
            .color('#E5E5E5')
            .margin({ left: 16, right: 16 })

          EffectLevelOption({
            level: EffectLevel.LOW,
            label: '低',
            desc: '轻微光晕，低调优雅'
          })

          Divider()
            .strokeWidth(0.5)
            .color('#E5E5E5')
            .margin({ left: 16, right: 16 })

          EffectLevelOption({
            level: EffectLevel.MEDIUM,
            label: '中',
            desc: '适中光感，推荐选择'
          })

          Divider()
            .strokeWidth(0.5)
            .color('#E5E5E5')
            .margin({ left: 16, right: 16 })

          EffectLevelOption({
            level: EffectLevel.HIGH,
            label: '高',
            desc: '强烈光效，视觉震撼'
          })
        }
        .width('100%')
        .borderRadius(12)
        .margin({ left: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.bgSecondary)
      .padding({ top: this.statusBarHeight + 118 })
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: '沉浸光感设置' }
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
}
