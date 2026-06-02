import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AudioSessionService } from '../services/AudioSessionService';
import { ThemeManager } from '../services/ThemeManager';
import { StorageService } from '../services/StorageService';
import { ImageCacheService } from '../services/ImageCacheService';
import { EffectLevel } from '../models/MusicModel';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private audioSessionService: AudioSessionService = AudioSessionService.getInstance();
  private themeManager: ThemeManager = ThemeManager.getInstance();
  private storageService: StorageService = StorageService.getInstance();
  private imageCacheService: ImageCacheService = ImageCacheService.getInstance();
  private mainWindow: window.Window | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    // 初始化主题（从存储加载偏好）
    this.storageService.setContext(this.context);
    const savedDark: boolean = await this.storageService.getThemeDark();
    this.themeManager.init(savedDark);

    // 加载沉浸光感效果档位
    const savedLevel: EffectLevel = await this.storageService.getEffectLevel();
    AppStorage.setOrCreate<number>('effectLevel', savedLevel);

    // 加载背景图片设置
    const savedBgImage: string = await this.storageService.getBgImage();
    AppStorage.setOrCreate<string>('bgImage', savedBgImage);
    const savedBgOpacity: number = await this.storageService.getBgOpacity();
    AppStorage.setOrCreate<number>('bgOpacity', savedBgOpacity);

    // 设置系统色彩模式
    try {
      this.context.getApplicationContext().setColorMode(this.themeManager.getColorMode());
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // 监听主题变化，实时更新系统栏样式
    this.themeManager.addListener((isDark: boolean) => {
      this.updateSystemBars();
      try {
        this.context.getApplicationContext().setColorMode(
          isDark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
            : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        );
      } catch (err) {
        // ignore
      }
    });

    // 初始化音频会话服务
    try {
      await this.audioSessionService.init(this.context);
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'AudioSessionService initialized');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init AudioSessionService: %{public}s', JSON.stringify(err));
    }

    // 初始化封面图缓存服务
    try {
      await this.imageCacheService.init(this.context);
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'ImageCacheService initialized');
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to init ImageCacheService: %{public}s', JSON.stringify(err));
    }
  }

  async onDestroy(): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');

    try {
      await this.audioSessionService.destroy();
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to destroy AudioSessionService: %{public}s', JSON.stringify(err));
    }
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 设置沉浸式全屏布局
    this.mainWindow = await windowStage.getMainWindow();
    this.mainWindow.setWindowLayoutFullScreen(true);

    // 获取安全区域高度，存入 AppStorage 供全局使用
    const avoidArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    AppStorage.setOrCreate<number>('statusBarHeight', px2vp(avoidArea.topRect.height));
    AppStorage.setOrCreate<number>('bottomNavBarHeight', px2vp(avoidArea.bottomRect.height));

    this.updateSystemBars();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private updateSystemBars(): void {
    if (!this.mainWindow) {
      return;
    }
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: this.themeManager.getStatusBarContentColor(),
      navigationBarContentColor: this.themeManager.getNavigationBarContentColor(),
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}