import { AppLog } from '../logging/AppLog';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

export class SecureStorage {
  /**
   * 保存敏感数据 (如果存在则更新)
   * @param alias 别名（Key）
   * @param secret 敏感数据（Value）
   */
  static async save(alias: string, secret: string): Promise<void> {
    const secretBytes = new util.TextEncoder().encodeInto(secret);

    // 1. 尝试新增
    try {
      const addQuery: asset.AssetMap = new Map();
      addQuery.set(asset.Tag.SECRET, secretBytes);
      addQuery.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(alias));
      // 设置访问控制：例如仅解锁设备后可访问，或者默认开机可访问
      addQuery.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      // 冲突策略：如果已存在，则覆盖 (API 11+ 支持，旧版本可能需要先删后加)
      addQuery.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);

      await asset.add(addQuery);
      AppLog.info('Native', `[SecureStorage] Saved ${alias} successfully.`);
    } catch (e) {
      AppLog.error('Native', `[SecureStorage] Save failed: ${JSON.stringify(e)}`);
      throw Error(e);
    }
  }

  /**
   * 读取敏感数据
   * @param alias 别名
   * @returns 明文数据 or ''
   */
  static async get(alias: string): Promise<string> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(alias));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL); // 请求返回所有属性（包括明文）

      const result = await asset.query(query);
      if (result.length > 0) {
        const secretBytes = result[0].get(asset.Tag.SECRET) as Uint8Array;
        if (secretBytes) {
          return new util.TextDecoder().decodeWithStream(secretBytes);
        }
      }
      return '';
    } catch (e) {
      const err = e as BusinessError;
      // 如果是“未找到”错误，返回空字符串，否则打印日志
      if (err.code !== asset.ErrorCode.NOT_FOUND) {
        AppLog.error('Native', `[SecureStorage] Get failed: ${JSON.stringify(e)}`);
      }
      return '';
    }
  }

  /**
   * 删除敏感数据
   */
  static async delete(alias: string): Promise<void> {
    try {
      const query: asset.AssetMap = new Map();
      query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(alias));
      await asset.remove(query);
    } catch (e) {
      // 忽略未找到的错误
      const err = e as BusinessError;
      if (err.code !== asset.ErrorCode.NOT_FOUND) {
        AppLog.error('Native', `[SecureStorage] Delete failed: ${JSON.stringify(e)}`);
      }
    }
  }
}