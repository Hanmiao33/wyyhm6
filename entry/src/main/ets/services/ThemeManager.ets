import { ConfigurationConstant } from '@kit.AbilityKit';

const THEME_MODE_KEY: string = 'theme_mode';

export interface ThemeColors {
  bgPrimary: string;
  bgSecondary: string;
  bgSurface: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  accent: string;
  accentLight: string;
  border: string;
  overlay: string;
}

const LIGHT_COLORS: ThemeColors = {
  bgPrimary: '#FFFFFF',
  bgSecondary: '#F5F5F5',
  bgSurface: '#FAFAFA',
  textPrimary: '#000000',
  textSecondary: '#000000',
  textTertiary: '#000000',
  accent: '#FF6B6B',
  accentLight: '#FFF0F0',
  border: '#E5E5E5',
  overlay: '#00000060',
};

const DARK_COLORS: ThemeColors = {
  bgPrimary: '#1A1A1A',
  bgSecondary: '#121212',
  bgSurface: '#2C2C2C',
  textPrimary: '#FFFFFF',
  textSecondary: '#CCCCCC',
  textTertiary: '#FFFFFF',
  accent: '#FF6B6B',
  accentLight: '#3A1A1A',
  border: '#3A3A3A',
  overlay: '#00000080',
};

export class ThemeManager {
  private static instance: ThemeManager;
  private isDark: boolean = false;
  private listeners: ((isDark: boolean) => void)[] = [];

  private constructor() {}

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  init(isDark: boolean): void {
    this.isDark = isDark;
    this.syncToStorage();
  }

  toggleTheme(): void {
    this.isDark = !this.isDark;
    this.syncToStorage();
    for (const listener of this.listeners) {
      listener(this.isDark);
    }
  }

  getIsDark(): boolean {
    return this.isDark;
  }

  getColors(): ThemeColors {
    return this.isDark ? DARK_COLORS : LIGHT_COLORS;
  }

  getStatusBarContentColor(): string {
    return this.isDark ? '#FFFFFF' : '#000000';
  }

  getNavigationBarContentColor(): string {
    return this.isDark ? '#FFFFFF' : '#000000';
  }

  getColorMode(): ConfigurationConstant.ColorMode {
    return this.isDark
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }

  addListener(listener: (isDark: boolean) => void): void {
    this.listeners.push(listener);
  }

  removeListener(listener: (isDark: boolean) => void): void {
    const index: number = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  private syncToStorage(): void {
    AppStorage.setOrCreate<boolean>('isDark', this.isDark);
    const colors: ThemeColors = this.getColors();
    AppStorage.setOrCreate<string>('bgPrimary', colors.bgPrimary);
    AppStorage.setOrCreate<string>('bgSecondary', colors.bgSecondary);
    AppStorage.setOrCreate<string>('bgSurface', colors.bgSurface);
    AppStorage.setOrCreate<string>('textPrimary', colors.textPrimary);
    AppStorage.setOrCreate<string>('textSecondary', colors.textSecondary);
    AppStorage.setOrCreate<string>('textTertiary', colors.textTertiary);
    AppStorage.setOrCreate<string>('accent', colors.accent);
    AppStorage.setOrCreate<string>('accentLight', colors.accentLight);
    AppStorage.setOrCreate<string>('border', colors.border);
    AppStorage.setOrCreate<string>('overlay', colors.overlay);
  }
}
