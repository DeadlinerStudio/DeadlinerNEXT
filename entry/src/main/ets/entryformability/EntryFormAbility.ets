import { AppLog } from '../common/logging/AppLog';
import { FormExtensionAbility, formInfo, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { WidgetUpdater } from '../utils/WidgetUpdater';
import { WidgetData } from '../widget/model/WidgetData';
import { CapsuleWidgetData } from '../widget/model/CapsuleWidgetData';
import { HudWidgetData } from '../widget/model/HudWidgetData';

interface TextColor {
  mTextColor: string;
  mWallpaperType: number;
}

export default class EntryFormAbility extends FormExtensionAbility {

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters![formInfo.FormParam.IDENTITY_KEY] as string;
    const formName = want.parameters![formInfo.FormParam.NAME_KEY] as string;

    AppLog.info('Native', `[EntryFormAbility] onAddForm: id=${formId}, name=${formName}`);

    this.saveFormInfo(formId, formName);

    setTimeout(() => {
      WidgetUpdater.updateAllWidgets(this.context);
    }, 50);

    let textColor = '#FFFFFF';
    if (want.parameters) {
      textColor = this.extractTextColor(want.parameters);
    }

    if (formName === 'widget_capsule'|| formName === 'widget_lock_capsule') {
      const capsuleData = new CapsuleWidgetData();
      capsuleData.remainingCount = 0;
      capsuleData.summary = "加载中...";
      return formBindingData.createFormBindingData({
        'widgetData': capsuleData
      });

    } else if (formName === 'widget_transparent_clock_card') {
      const hudData = new HudWidgetData();
      hudData.dateStr = "加载中...";
      hudData.urgentTaskName = "正在同步数据...";

      return formBindingData.createFormBindingData({
        'hudData': hudData,
        'textColor': textColor
      });
    } else {
      const listData = new WidgetData();
      listData.totalCount = 0;
      listData.tasks = [];
      return formBindingData.createFormBindingData(listData);
    }
  }

  onRemoveForm(formId: string) {
    AppLog.info('Native', `[EntryFormAbility] onRemoveForm: ${formId}`);
    this.deleteFormInfo(formId);
  }

  onUpdateForm(formId: string, wantParams?: Record<string, Object>) {
    AppLog.info('Native', `[EntryFormAbility] onUpdateForm: ${formId}`);

    if (wantParams) {
      const textColor = this.extractTextColor(wantParams);
      const formData = formBindingData.createFormBindingData({ 'textColor': textColor });
      formProvider.updateForm(formId, formData).catch((err: Error) => {
        AppLog.error('Native', `[EntryFormAbility] updateColor failed: ${JSON.stringify(err)}`);
      });
    }

    WidgetUpdater.updateAllWidgets(this.context);
  }

  private extractTextColor(params: Record<string, Object>): string {
    let textColor = '#FFFFFF';
    try {
      const colorKey = formInfo.FormParam.HOST_BG_INVERSE_COLOR_KEY;
      if (params[colorKey]) {
        const colorObj = params[colorKey] as TextColor;
        if (colorObj && colorObj.mTextColor) {
          textColor = colorObj.mTextColor;
          AppLog.info('Native', `[EntryFormAbility] Color extracted: ${textColor}`);
        }
      }
    } catch (e) {
      AppLog.error('Native', `[EntryFormAbility] extractTextColor error: ${e}`);
    }
    return textColor;
  }

  // === Preferences 辅助方法 (已升级支持存储类型) ===

  private async saveFormInfo(formId: string, formName: string) {
    try {
      const pref = await preferences.getPreferences(this.context, 'widget_store');

      // 1. 维护 ID 列表 (为了遍历)
      const ids = (await pref.get('formIds', [])) as Array<string>;
      if (!ids.includes(formId)) {
        ids.push(formId);
        await pref.put('formIds', ids);
      }

      // 2. 【关键】存储 "ID -> 卡片类型" 的映射
      // 这样 WidgetUpdater 在 updateAllWidgets 时，可以先 get(formId) 知道它是谁
      await pref.put(formId, formName);

      await pref.flush();
    } catch (e) {
      AppLog.error('Native', `[EntryFormAbility] Save Form Info failed: ${e}`);
    }
  }

  private async deleteFormInfo(formId: string) {
    try {
      const pref = await preferences.getPreferences(this.context, 'widget_store');

      // 1. 移除 ID
      let ids = (await pref.get('formIds', [])) as Array<string>;
      ids = ids.filter(id => id !== formId);
      await pref.put('formIds', ids);

      // 2. 移除类型映射
      if (await pref.has(formId)) {
        await pref.delete(formId);
      }

      await pref.flush();
    } catch (e) {
      AppLog.error('Native', `[EntryFormAbility] Delete Form Info failed: ${e}`);
    }
  }
};