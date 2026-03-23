import { SettingsConstants as C } from '../../common/local/SettingsConstants';
import { ITheme } from '../../common/theme/ThemeModel';
import { Habit, HabitGoalType, HabitPeriod, HabitRecordStatus } from '../../model/DDLModels';
import { DDLStatus } from '../../model/DDLStatus';
import { ColorUtils } from '../../utils/ColorUtils';

// 接口定义保持不变
export interface DayOverview {
  date: Date;
  completedCount: number;
  totalCount: number;
  completionRatio: number;
}

export interface HabitWithDailyStatus {
  habit: Habit;
  doneCount: number;
  targetCount: number;
  isCompleted: boolean;
}

@Component
export struct HabitProgress {
  // 必须接收 progress，否则子组件无法获取数据
  @Prop progress: number = 0;
  @StorageProp(C.KEY_HABIT_PROGRESS_STYLE) style: string = 'ellipse';

  build() {
    Column() {
      if (this.style === 'linear') {
        HabitLinearProgress({ progress: this.progress })
      } else if (this.style === 'ring') {
        HabitRingProgress({ progress: this.progress })
      } else {
        HabitEllipseProgress({ progress: this.progress })
      }
    }
    // 加上动画，让样式切换时平滑过渡
    .animation({ duration: 300, curve: Curve.EaseInOut })
  }
}

@Component
struct HabitRingProgress {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop progress: number;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Ring })
        .width(84)
        .height(84)
        .color(this.theme.brand) // 进度条颜色
        // .backgroundColor($r('app.color.brand_10')) // 可选：底轨颜色
        .style({ strokeWidth: 8 }) // 环的粗细
        .animation({ duration: 800, curve: Curve.Smooth })

      Column() {
        Text(`${(this.progress * 100).toFixed(0)}%`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
      }
    }
  }
}

@Component
struct HabitLinearProgress {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop progress: number;

  build() {
    Column() {
      // 为了美观，Linear 模式通常文字在上面或侧面，这里采用上下布局
      Row() {
        Text("今日完成度")
          .fontSize(12)
          .fontColor($r('app.color.font_secondary'))

        Blank()

        Text(`${(this.progress * 100).toFixed(0)}%`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.font_primary'))
      }
      .width('100%')
      .margin({ bottom: 8 })
      .padding({ left: 4, right: 4 })

      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Linear })
        .width('100%') // 撑满宽度
        .height(12)    // 稍微加粗一点
        .color(this.theme.brand)
        // .backgroundColor($r('app.color.background_secondary'))
        .style({ strokeWidth: 12, enableSmoothEffect: true })
        .animation({ duration: 800, curve: Curve.Smooth })
    }
    .width('90%')
    .justifyContent(FlexAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}

@Component
export struct HabitEllipseProgress {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop progress: number;

  build() {
    Stack({ alignContent: Alignment.Center }) {

      Progress({ value: this.progress * 100, total: 100, type: ProgressType.Eclipse })
        .width(84)
        .height(84)
        .color(this.theme.brand50)
        .animation({ duration: 800, curve: Curve.Smooth })

      Text(`${(this.progress * 100).toFixed(0)}%`)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.font_primary'))
    }
  }
}

@Component
export struct WeekRow {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  // 数据源
  @Prop weekOverview: DayOverview[];
  @Prop selectedDate: Date;
  @Prop currentDate: Date = new Date();

  // 回调
  onSelectDate: (d: Date) => void = () => {};
  onChangeWeek: (offset: number) => void = () => {};

  @StorageProp(C.KEY_ENGLISH_SOMEWHERE)
  englishSomewhere: boolean = true;

  // 动画状态
  @State animOffset: number = 0; // X轴偏移量
  @State animOpacity: number = 1; // 透明度

  // 颜色定义
  private primaryColor: ResourceColor = this.theme.brand;
  private bgColor: ResourceColor = this.theme.brand50;
  private secondaryColor: ResourceColor = $r('app.color.font_secondary');
  private primaryFontColor: ResourceColor = $r('app.color.font_primary');

  // --- 逻辑判断方法 ---
  private isSameDay(d1: Date, d2: Date): boolean {
    return d1.getDate() === d2.getDate() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getFullYear() === d2.getFullYear();
  }

  private getDayLabel(date: Date): string {
    const english = this.englishSomewhere;
    const days = english ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] : ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return days[date.getDay()];
  }

  private getDayLabelColor(date: Date): ResourceColor {
    return this.isSameDay(date, this.currentDate) ? this.primaryColor : this.secondaryColor;
  }

  private getDayLabelWeight(date: Date): FontWeight {
    return this.isSameDay(date, this.currentDate) ? FontWeight.Bold : FontWeight.Normal;
  }

  private getDateBgColor(date: Date): ResourceColor {
    return this.isSameDay(date, this.selectedDate) ? this.bgColor : Color.Transparent;
  }

  private getDateTextColor(date: Date): ResourceColor {
    const isToday = this.isSameDay(date, this.currentDate);
    const isSelected = this.isSameDay(date, this.selectedDate);
    if (isToday) return this.primaryColor;
    if (isSelected) return this.primaryFontColor;
    return this.secondaryColor;
  }

  private getDateFontWeight(date: Date): FontWeight {
    const isToday = this.isSameDay(date, this.currentDate);
    const isSelected = this.isSameDay(date, this.selectedDate);
    return (isToday || isSelected) ? FontWeight.Bold : FontWeight.Medium;
  }

  private getMonthTitle(): string[] {
    if (!this.weekOverview || this.weekOverview.length === 0) return ['', ''];
    const firstDay = this.weekOverview[0].date;
    return [`${firstDay.getFullYear()}`, `${firstDay.getMonth() + 1}`];
  }

  @Builder
  MonthTitle() {
    Row() {
      Text(this.getMonthTitle()[0])
        .fontSize('16vp')
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryFontColor)
        .textAlign(TextAlign.Center)
        .opacity(this.animOpacity)
        .animation({ duration: 200 })

      Text(' / ')
        .fontSize('16vp')
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.brand)
        .textAlign(TextAlign.Center)
        .opacity(this.animOpacity)
        .animation({ duration: 200 })

      Text(this.getMonthTitle()[1])
        .fontSize('16vp')
        .fontWeight(FontWeight.Medium)
        .fontColor(this.primaryFontColor)
        .textAlign(TextAlign.Center)
        .opacity(this.animOpacity)
        .animation({ duration: 200 })
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
  }

  // --- 核心动画逻辑 ---

  /**
   * 执行切换动画
   * @param direction -1: 上一周(右滑), 1: 下一周(左滑)
   */
  private triggerSwitchAnimation(direction: number) {
    const screenWidth = 300;

    animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.animOffset = direction === 1 ? -screenWidth : screenWidth;
      this.animOpacity = 0;
    });

    setTimeout(() => {
      this.onChangeWeek(direction);

      this.animOffset = direction === 1 ? screenWidth : -screenWidth;

      animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.animOffset = 0;
        this.animOpacity = 1;
      });
    }, 200);
  }

  // --- UI 构建 ---

  @Builder
  DayItem(day: DayOverview) {
    Column() {
      Text(this.getDayLabel(day.date))
        .fontSize('12vp')
        .fontColor(this.getDayLabelColor(day.date))
        .fontWeight(this.getDayLabelWeight(day.date))
        .margin({ bottom: 4 })

      Column() {
        Text(day.date.getDate().toString())
          .fontSize('16vp')
          .fontWeight(this.getDateFontWeight(day.date))
          .fontColor(this.getDateTextColor(day.date))
      }
      .justifyContent(FlexAlign.Center)
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(this.getDateBgColor(day.date))

      if (day.completionRatio > 0) {
        Circle()
          .width(5)
          .height(5)
          .fill(this.primaryColor)
          .margin({ top: 4 })
      } else {
        Blank().height(5).margin({ top: 4 })
      }
    }
    .width('100%')
    .onClick(() => this.onSelectDate(day.date))
  }

  build() {
    Column() {
      // 顶部操作栏
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize('20vp')
            .fontColor([this.secondaryColor])
        }
        .backgroundColor(Color.Transparent)
        .width(32)
        .height(32)
        .onClick(() => this.triggerSwitchAnimation(-1))

        this.MonthTitle()

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize('20vp')
            .fontColor([this.secondaryColor])
        }
        .backgroundColor(Color.Transparent)
        .width(32)
        .height(32)
        .onClick(() => this.triggerSwitchAnimation(1))
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Column() {
        List() {
          ForEach(this.weekOverview, (day: DayOverview) => {
            ListItem() {
              this.DayItem(day)
            }
            .width(`${100 / 7}%`)
          })
        }
        .listDirection(Axis.Horizontal)
        .width('100%')
        .height(56)
        .translate({ x: this.animOffset })
        .opacity(this.animOpacity)
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionUpdate((event: GestureEvent) => {
              // 1. 跟随手指移动 (阻尼效果可选，这里直接跟随)
              this.animOffset = event.offsetX;
            })
            .onActionEnd((event: GestureEvent) => {
              const threshold = 60; // 触发切换的阈值距离

              if (event.offsetX < -threshold) {
                // 左滑距离足够 -> 下一周
                this.triggerSwitchAnimation(1);
              } else if (event.offsetX > threshold) {
                // 右滑距离足够 -> 上一周
                this.triggerSwitchAnimation(-1);
              } else {
                // 距离不够 -> 回弹复位
                animateTo({ duration: 300, curve: Curve.Rhythm }, () => {
                  this.animOffset = 0;
                });
              }
            })
        )
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
      .clip(true)
    }
  }
}

@Component
struct HabitSelectionOverlay {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @State primaryColor: ResourceColor = this.theme.brand; // 默认值，实际会由 theme 覆盖
  @State containerColor: ResourceColor = this.theme.bgPrimary;
  @State onPrimaryColor: ResourceColor = Color.White;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 半透明遮罩背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.containerColor)
        .opacity(0.25)

      // 2. 边框
      Column()
        .width('100%')
        .height('100%')
        .border({
          width: 2,
          color: this.primaryColor,
          radius: 24 // 这里的 radius 要和卡片保持一致
        })
        .opacity(0.7)
        .hitTestBehavior(HitTestMode.Transparent)

      // 3. 左上角打钩
      Stack() {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(16)
          .fontColor([this.onPrimaryColor])
      }
      .width(24)
      .height(24)
      .borderRadius(12)
      .backgroundColor(this.primaryColor)
      .shadow({ radius: 2 })
      .margin({ top: 8, left: 8 })
      .alignContent(Alignment.Center)
    }
    .width('100%')
    .height('100%')
  }
}

@Component
export struct HabitRow {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop data: HabitWithDailyStatus;
  @Prop status: DDLStatus;
  @Prop isSelected: boolean;
  @Prop canToggle: boolean;
  @Prop remainingText: string;

  onToggle: () => void = () => {};
  onLongPress: () => void = () => {};

  @State private titleColor: ResourceColor = $r('app.color.font_primary');
  @State private noteColor: ResourceColor = $r('app.color.font_secondary');

  // --- 1. 获取纯色 (用于 Checkbox 选中色) ---
  private getIndicatorColor(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return this.theme.indicatorUndergo;
      case DDLStatus.NEAR: return this.theme.indicatorNear;
      case DDLStatus.PASSED: return this.theme.indicatorPassed;
      case DDLStatus.COMPLETED: return this.theme.indicatorCompleted;
      default: return this.theme.indicatorUndergo;
    }
  }

  // --- 2. 新增：获取 50% 透明度的主色 (用于渐变起色) ---
  private getIndicatorColor50(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return this.theme.indicatorUndergo50;
      case DDLStatus.NEAR: return this.theme.indicatorNear50;
      case DDLStatus.PASSED: return this.theme.indicatorPassed50;
      case DDLStatus.COMPLETED: return this.theme.indicatorCompleted50;
      default: return this.theme.indicatorUndergo50;
    }
  }

  // --- 3. 新增：获取 70% 透明度的主色 (用于渐变终色) ---
  private getIndicatorColor70(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return this.theme.indicatorUndergo70;
      case DDLStatus.NEAR: return this.theme.indicatorNear70;
      case DDLStatus.PASSED: return this.theme.indicatorPassed70;
      case DDLStatus.COMPLETED: return this.theme.indicatorCompleted70;
      default: return this.theme.indicatorUndergo70;
    }
  }

  // --- 4. 新增：获取 40% 透明度的背景色 (用于底色) ---
  private getBgColor40(): ResourceColor {
    switch (this.status) {
      case DDLStatus.UNDERGO: return this.theme.bgUndergo40;
      case DDLStatus.NEAR: return this.theme.bgNear40;
      case DDLStatus.PASSED: return this.theme.bgPassed40;
      case DDLStatus.COMPLETED: return this.theme.bgCompleted40;
      default: return this.theme.bgUndergo40;
    }
  }

  private getBottomLine(): string {
    let bottomLine = `${this.data.doneCount}/${this.data.targetCount}`;
    if (this.data.habit.goalType === HabitGoalType.TOTAL) {
      const total = this.data.habit.totalTarget ? this.data.habit.totalTarget : "∞";
      bottomLine = `${this.data.doneCount}/${total}`;
    }
    if (this.remainingText) {
      bottomLine = `${this.remainingText} · ${bottomLine}`;
    }
    return bottomLine;
  }

  private getRightLabel(): string {
    if (this.data.habit.goalType === HabitGoalType.PER_PERIOD) {
      return this.data.habit.period.toString();
    } else {
      return "Total";
    }
  }

  private getProgress(): number {
    return Math.min(1, Math.max(0, this.data.doneCount / Math.max(1, this.data.targetCount)));
  }

  build() {
    Stack() {
      // 1. 内容层
      Stack({ alignContent: Alignment.Start }) {
        // 底色：直接使用对应的资源 Getter
        Rect()
          .width('100%')
          .height('100%')
          .fill(this.getBgColor40())

        // 进度条前景
        if (this.getProgress() > 0) {
          Row()
            .width(`${this.getProgress() * 100}%`)
            .height('100%')
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [
                // 渐变色：直接使用对应的资源 Getter
                [this.getIndicatorColor50(), 0.0],
                [this.getIndicatorColor70(), 1.0]
              ]
            })
            .animation({ duration: 800, curve: Curve.Smooth })
        }

        // 文本内容行
        Row() {
          Checkbox({ name: 'done', group: 'habit' })
            .select(this.data.isCompleted)
            .selectedColor(this.getIndicatorColor()) // 选中色保持使用纯色
            .onChange(() => {
              if (this.canToggle) this.onToggle();
            })
            .enabled(this.canToggle)
            .margin({ right: 12 })

          Column() {
            Text(this.data.habit.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.titleColor)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .maxLines(1)

            Text(this.getBottomLine())
              .fontSize(12)
              .fontColor(this.noteColor)
              .margin({ top: 4 })
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(this.getRightLabel())
            .fontSize(10)
            .fontColor(this.noteColor)
        }
        .padding({ left: 12, right: 12, top: 12, bottom: 12 })
        .width('100%')
        .height(72)
      }
      .width('100%')
      .height(72)

      // 选中态遮罩层
      if (this.isSelected) {
        HabitSelectionOverlay()
      }
    }
    .width('100%')
    .height(72)
    .borderRadius(24)
    .clip(true)
    .onClick(() => {
      if (this.canToggle) this.onToggle();
    })
    .gesture(
      LongPressGesture()
        .onAction(() => this.onLongPress())
    )
    .backgroundBlurStyle(BlurStyle.Regular)
  }
}