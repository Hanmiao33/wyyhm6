/**
 * 图片 URL 工具
 * 网易云音乐支持 ?param=WxH 获取指定尺寸缩略图
 */

/**
 * 生成缩略图 URL
 * @param url 原始封面 URL
 * @param width 目标宽度
 * @param height 目标高度
 * @returns 带 ?param=WxH 的缩略图 URL
 */
export function thumbnail(url: string, width: number, height: number): string {
  if (!url) {
    return '';
  }
  // 已经有 ?param 则替换
  const base: string = url.split('?')[0];
  return `${base}?param=${width}y${height}`;
}
