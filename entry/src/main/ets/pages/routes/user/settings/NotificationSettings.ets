import { LocalValues } from '../../../../common/local/LocalValues';
import { SettingsConstants as C } from '../../../../common/local/SettingsConstants';
import { SettingsDivider, SettingsSection,
  SubSettingsDivider,
  SubSettingsSwitch } from '../../../components/SettingsComponents';
import { HdsNavDestination, HdsNavDestinationAttribute } from '@kit.UIDesignKit';
import { TopSafeContainer } from '../../../components/TopSafeContainer';
import { notificationManager } from '@kit.NotificationKit';
import { ReminderScheduler } from '../../../../utils/notification/ReminderScheduler';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

// 引入 Repository 用于触发数据刷新
import { TaskRepository } from '../../../../common/repository/TaskRepository';
import { HabitRepository } from '../../../../common/repository/HabitRepository';
import { getImmersiveTitleBarStyle } from '../../../../common/style/NavStyles';
import { ITheme } from '../../../../common/theme/ThemeModel';

@Builder
export function NotificationSettingsBuilder() {
  NotificationSettings()
}

@Component
struct NotificationSettings {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageLink('isWideScreen') isWideScreen: boolean = false;

  @StorageLink('statusBarHeight') statusBarHeight: number = 38;
  @StorageLink('topAvoidExtraHeight') topAvoidExtraHeight: number = 0;
  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // --- 1. 系统权限状态 (Source of Truth 是 OS，所以用 @State) ---
  @State allowNotification: boolean = false;

  // --- 2. 业务配置 (Source of Truth 是 AppStorage，用 @StorageLink) ---
  // 这里的 Key 必须和 LocalValues.init() 里 setOrCreate 的 Key 一致
  @StorageLink(C.KEY_NOTIFY_DDL_WARNING) ddlWarning: boolean = true;
  @StorageLink(C.KEY_NOTIFY_HABIT_REMINDER) habitReminder: boolean = true;
  @StorageLink(C.KEY_NOTIFY_SUMMARY_ENABLE) dailySummary: boolean = false;
  @StorageLink(C.KEY_NOTIFY_SUMMARY_TIME) summaryTime: string = "21:00";

  // 防抖时间戳
  private lastSummaryClickTime: number = 0;

  async aboutToAppear() {
    // 只需要检查系统权限，其他的 @StorageLink 会自动从 AppStorage 加载
    await this.checkSystemPermission();
  }

  /**
   * 检查系统通知权限并同步 UI
   */
  async checkSystemPermission() {
    try {
      const isEnabled = await notificationManager.isNotificationEnabled();
      this.allowNotification = isEnabled;
    } catch (e) {
      console.error('Check permission failed:', e);
    }
  }

  /**
   * 获取 Picker 需要的 Date 对象
   */
  private getSelectedDate(): Date {
    const now = new Date();
    try {
      const parts = this.summaryTime.split(':'); // summaryTime 已经是 StorageLink，直接用
      now.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0);
    } catch (e) {
      now.setHours(21, 0, 0, 0);
    }
    return now;
  }

  build() {
    HdsNavDestination() {
      TopSafeContainer({ topAvoidHeight: this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT + this.topAvoidExtraHeight }) {
        Column({ space: 16 }) {

          // =========================================================
          // 1. 系统权限 (总开关)
          // =========================================================
          SettingsSection() {
            SubSettingsSwitch({
              title: "允许通知",
              isOn: this.allowNotification,
              onChange: (isOn) => {
                if (isOn && !this.allowNotification) {
                  // A. 用户想开启 -> 请求权限
                  notificationManager.requestEnableNotification().then(() => {
                    this.allowNotification = true;
                  }).catch(() => {
                    this.allowNotification = false;
                    promptAction.showToast({ message: '开启通知失败，请前往系统设置' });
                  });
                }
                else if (!isOn && this.allowNotification) {
                  // B. 用户想关闭 -> 引导去系统设置
                  this.allowNotification = true; // UI 强制回弹，因为只有系统能改
                  promptAction.showDialog({
                    title: '无法直接关闭',
                    message: '为了保证系统稳定性，请前往“系统设置-通知和状态栏”中关闭本应用的通知权限。',
                    buttons: [
                      { text: '知道了', color: '#007DFF' }
                    ]
                  });
                }
              }
            })
          }

          // =========================================================
          // 2. 细分设置 (只有系统允许通知时才可用)
          // =========================================================
          if (this.allowNotification) {
            SettingsSection({ title: '推送类型' }) {

              // --- DDL 预警 ---
              SubSettingsSwitch({
                title: "DDL 临近预警",
                subtitle: "智能检测临近截止日期的任务，并提前发送提醒。",
                isOn: this.ddlWarning, // 绑定 StorageLink
                onChange: (isOn) => {
                  // 1. StorageLink 会自动更新内存中的 AppStorage
                  // 2. 显式调用 LocalValues 进行持久化 (存入 Preferences)
                  LocalValues.getInstance().setDDLWarning(isOn);

                  // 3. 触发调度器刷新 (Scheduler 会读取最新的 Storage 值)
                  TaskRepository.getInstance().initialReminderCheck();
                }
              })

              SubSettingsDivider()

              // --- 每日摘要 ---
              SubSettingsSwitch({
                title: "每日摘要",
                subtitle: this.dailySummary ? `每天 ${this.summaryTime} 推送今日待办任务摘要。` : "每天定时推送今日待办任务摘要。",
                isOn: this.dailySummary,
                onChange: (isOn) => {
                  // 防抖
                  const now = Date.now();
                  if (now - this.lastSummaryClickTime < 500) return;
                  this.lastSummaryClickTime = now;

                  if (isOn) {
                    // 开启：先弹窗，用户确认后才真正开启
                    TimePickerDialog.show({
                      selected: this.getSelectedDate(),
                      useMilitaryTime: true,
                      selectedTextStyle: { color: this.theme.brand },
                      acceptButtonStyle: { fontColor: this.theme.brand },
                      cancelButtonStyle: { fontColor: this.theme.brand },
                      onAccept: (value: TimePickerResult) => {
                        const hour = value.hour.toString().padStart(2, '0');
                        const minute = value.minute.toString().padStart(2, '0');
                        const timeStr = `${hour}:${minute}`;

                        // 1. 更新 StorageLink
                        this.summaryTime = timeStr;
                        this.dailySummary = true;

                        // 2. 持久化
                        LocalValues.getInstance().setDailySummaryConfig(true, timeStr);

                        // 3. 刷新 Scheduler
                        ReminderScheduler.refreshDailySummary(timeStr);
                      },
                      onCancel: () => {
                        // 用户取消，强制回拨为 false
                        this.dailySummary = false;
                      }
                    })
                  } else {
                    // 关闭：直接执行
                    this.dailySummary = false;

                    // 持久化 (time 传 null 或保留原值均可，setDailySummaryConfig 内部处理逻辑要适配)
                    LocalValues.getInstance().setDailySummaryConfig(false, this.summaryTime);

                    // 刷新 (传 null 给 Scheduler 触发清理)
                    ReminderScheduler.refreshDailySummary(null);
                  }
                }
              })

              SubSettingsDivider()

              // --- 习惯打卡 ---
              SubSettingsSwitch({
                title: "习惯打卡提醒",
                subtitle: "在您设定的时间提醒您完成习惯打卡。",
                isOn: this.habitReminder,
                onChange: (isOn) => {
                  // 1. StorageLink 自动更新

                  // 2. 持久化
                  LocalValues.getInstance().setHabitReminder(isOn);

                  // 3. 触发刷新
                  HabitRepository.getInstance().initialReminderCheck();
                }
              })
            }

            Text('通知推送功能使用华为代理提醒API实现，可能会出现通知推送不及时的问题。待后续版本解决。')
              .fontSize(12)
              .lineHeight(16)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .padding({ left: 24, right: 24, top: 8, bottom: 24 })
              .width('100%')
          } else {
            // 权限关闭时的占位提示
            Text("开启通知权限后，可配置更多提醒选项。")
              .fontSize(14)
              .fontColor($r('app.color.font_secondary'))
              .padding({ top: 16, left: 16 })
          }
        }
        .width('100%')
        .padding(16)
        .justifyContent(FlexAlign.Start)
        .constraintSize({ minHeight: '100%' })
      }
    }
    .titleBar({
      avoidLayoutSafeArea: this.isWideScreen,
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: { title: { mainTitle: "通知与提醒" } }
    })
    .onShown(() => {
      // NavDestination 生命周期：页面显示时（包括从后台切回来，或从系统设置页切回来）
      this.checkSystemPermission();
    })
  }
}
