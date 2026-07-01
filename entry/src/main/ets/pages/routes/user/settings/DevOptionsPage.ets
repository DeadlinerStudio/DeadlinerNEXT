import { HdsNavDestination, HdsNavDestinationAttribute } from "@hms.hds.hdsBaseComponent"; // 根据你的实际 HDS 路径调整
import { notificationManager } from "@kit.NotificationKit";
import { promptAction } from "@kit.ArkUI";
import { reminderAgentManager } from "@kit.BackgroundTasksKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { ReminderUtils } from "../../../../utils/notification/ReminderUtils";
import { getImmersiveTitleBarStyle } from "../../../../common/style/NavStyles";
import { ITheme } from "../../../../common/theme/ThemeModel";

@Builder
export function DevOptionsBuilder(name: string, param: Object) {
  DevOptionsPage()
}

@Component
export struct DevOptionsPage {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @StorageLink('isWideScreen') isWideScreen: boolean = false;
  @StorageLink('statusBarHeight') statusBarHeight: number = 38;

  readonly TITLE_BAR_CONTENT_HEIGHT: number = 18;

  // 辅助方法：生成 toast
  private toast(msg: string) {
    promptAction.showToast({ message: msg, duration: 2000 });
  }

  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Blank()
            .height(this.isWideScreen ? this.statusBarHeight + this.TITLE_BAR_CONTENT_HEIGHT : 68)
            .width('100%')

          // =========================================================
          // 0. 清理环境
          // =========================================================
          Button('🗑️ 清空所有提醒 (Reset)')
            .backgroundColor('#D32F2F') // 红色警告色
            .width('90%')
            .height(50)
            .onClick(async () => {
              try {
                await reminderAgentManager.cancelAllReminders();
                this.toast('已清空所有后台提醒');
                console.info('[Dev] All reminders canceled.');
              } catch (e) {
                this.toast(`清空失败: ${JSON.stringify(e)}`);
              }
            })

          Divider().padding({ top: 10, bottom: 10 })

          // =========================================================
          // 1. 单元测试：单次 DDL (Calendar)
          // =========================================================
          Text("单元测试 A: 单次任务 (DDL)")
            .fontSize(14)
            .fontColor(Color.Gray)
            .width('90%')
            .textAlign(TextAlign.Start)

          Button('📅 发布 DDL (10秒后)')
            .backgroundColor($r('app.color.chart_green')) // 假设你有这个资源，或者用 '#4CAF50'
            .width('90%')
            .height(60)
            .onClick(async () => {
              try {
                // 1. 设定时间：当前时间 + 10秒
                const targetDate = new Date();
                targetDate.setSeconds(targetDate.getSeconds() + 10);

                // 2. 调用 API
                console.info(`[Dev] Testing Calendar DDL. Target: ${targetDate.toLocaleTimeString()}`);
                const id = await ReminderUtils.publishCalendar(
                  "DDL 测试",
                  `单次提醒，应该在 ${targetDate.toLocaleTimeString()} 触发`,
                  targetDate
                );

                this.toast(`✅ Calendar 发布成功 ID:${id}`);
              } catch (e) {
                const err = e as BusinessError;
                this.toast(`❌ 失败: ${err.code} - ${err.message}`);
                console.error(`[Dev] Calendar failed: ${JSON.stringify(err)}`);
              }
            })

          // =========================================================
          // 2. 单元测试：循环提醒 (Alarm)
          // =========================================================
          Text("单元测试 B: 循环/习惯 (Alarm)")
            .fontSize(14)
            .fontColor(Color.Gray)
            .width('90%')
            .textAlign(TextAlign.Start)

          Button('⏰ 发布习惯 (下一分钟)')
            .backgroundColor('#007DFF')
            .width('90%')
            .height(60)
            .onClick(async () => {
              try {
                // 1. 设定时间：下一分钟的 00 秒
                // 例如现在是 18:30:45，设定为 18:31:00
                const now = new Date();
                const nextMinute = new Date(now.getTime() + 60 * 1000);
                const hour = nextMinute.getHours();
                const minute = nextMinute.getMinutes();

                // 2. 设定重复：每天
                const days = [1, 2, 3, 4, 5, 6, 7];

                console.info(`[Dev] Testing Alarm Habit. Target: ${hour}:${minute}`);

                // 3. 调用 API
                const id = await ReminderUtils.publishAlarm(
                  "习惯打卡测试",
                  `这是 Alarm 类型，应在 ${hour}:${minute} 触发，且每天重复`,
                  hour,
                  minute,
                  days
                );

                this.toast(`✅ Alarm 发布成功 ID:${id}`);
                console.info(`[Dev] Alarm published. ID: ${id}`);

              } catch (e) {
                const err = e as BusinessError;
                this.toast(`❌ 失败: ${err.code} - ${err.message}`);
              }
            })

          Divider().padding({ top: 10, bottom: 10 })

          // =========================================================
          // 3. 状态诊断 (用于查证)
          // =========================================================
          Button('🔍 查看当前生效的提醒')
            .backgroundColor('#FF9800')
            .width('90%')
            .height(50)
            .onClick(async () => {
              try {
                console.info("============== DIAGNOSIS START ==============");

                // 1. 查权限
                const isEnable = await notificationManager.isNotificationEnabled();
                console.info(`[Status] Notification Perm: ${isEnable}`);

                // 2. 查数量
                const reminders = await reminderAgentManager.getValidReminders();
                console.info(`[Status] Valid Reminders Count: ${reminders.length}`);
                this.toast(`当前生效提醒数: ${reminders.length}`);

                // 3. 打印详细信息 (方便在 Logcat 看类型)
                reminders.forEach((r, index) => {
                  // 这里我们需要把 r 强转一下或者用 JSON 查看，因为类型定义可能不全
                  // type: 1=TIMER, 2=CALENDAR, 3=ALARM
                  console.info(`[Reminder #${index}] ID:${r.notificationId} Type:${r.reminderType} Title:${r.title}`);
                  if (r.reminderType === reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM) {
                    // 验证 Alarm 的重复属性
                    const alarm = r as reminderAgentManager.ReminderRequestAlarm;
                    console.info(`   -> Alarm Days: ${JSON.stringify(alarm.daysOfWeek)} Hour:${alarm.hour}:${alarm.minute}`);
                  }
                });

                console.info("============== DIAGNOSIS END ==============");
              } catch (err) {
                this.toast(`诊断失败: ${JSON.stringify(err)}`);
              }
            })

        }
        .width('100%')
        .padding({ bottom: 50 })
        .justifyContent(FlexAlign.Start)
      }
    }
    .titleBar({
      avoidLayoutSafeArea: this.isWideScreen,
      style: getImmersiveTitleBarStyle(this.isWideScreen),
      content: {
        title: {
          mainTitle: '提醒服务 API 测试'
        }
      }
    })
    .backgroundColor(this.theme.bgPrimary)
  }
}
