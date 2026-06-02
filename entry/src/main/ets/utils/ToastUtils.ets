import promptAction from '@ohos.promptAction';

export class ToastUtils {
  static showToast(message: string, duration: number = 2000) {
    promptAction.showToast({
      message: message,
      duration: duration
    });
  }

  static showSuccess(message: string) {
    this.showToast(`✓ ${message}`);
  }

  static showError(message: string) {
    this.showToast(`✕ ${message}`);
  }

  static showWarning(message: string) {
    this.showToast(`⚠ ${message}`);
  }
}
