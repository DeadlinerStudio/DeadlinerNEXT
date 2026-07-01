import { OverviewViewModel, OverviewCard, TrendCard } from './OverviewViewModel';
import { vibrator } from '@kit.SensorServiceKit';
import { VibrationUtils } from '../../../utils/VibrationUtils';

@Component
export struct SortSheet {
  @Link viewModel: OverviewViewModel;
  @Prop selectedTabIndex: number;
  onClose: () => void = () => {};

  @State gridWidth: number = 0;

  // --- 震动反馈 ---
  private triggerVibration() {
    VibrationUtils.vibrateTouch();
  }

  // --- 卡片样式 (复用之前的漂亮设计) ---
  @Builder SortItemCard(name: string, isDragging: boolean) {
    Row() {
      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
        .fontSize(24)
        .fontColor([isDragging ? $r('sys.color.ohos_id_color_text_primary') : $r('sys.color.ohos_id_color_text_tertiary')])
        .margin({ right: 16 })

      Text(name)
        .fontSize(16)
        .fontWeight(isDragging ? FontWeight.Bold : FontWeight.Medium)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .height(72)
    .padding({ left: 20, right: 20 })
    .backgroundColor(isDragging ? $r('sys.color.ohos_id_color_card_bg') : Color.Transparent)
    .borderRadius(isDragging ? 16 : 0)
    .shadow(isDragging ? { radius: 30, color: 'rgba(0,0,0,0.2)', offsetY: 10 } : undefined)
    .scale(isDragging ? { x: 1.05, y: 1.05 } : { x: 1, y: 1 })
  }

  @Builder pixelMapBuilder(itemIndex: number) {
    Column() {
      if (this.selectedTabIndex === 0) {
        this.SortItemCard(this.getOverviewCardName(this.viewModel.overviewCardOrder[itemIndex]), true)
      } else {
        this.SortItemCard(this.getTrendCardName(this.viewModel.trendCardOrder[itemIndex]), true)
      }
    }
    .width(this.gridWidth)
  }

  build() {
    Column() {

      // --- 【核心修改】使用 Grid 替代 List ---
      Grid() {
        if (this.selectedTabIndex === 0) {
          ForEach(this.viewModel.overviewCardOrder, (cardId: OverviewCard, index: number) => {
            GridItem() { // List -> GridItem
              this.SortItemCard(this.getOverviewCardName(cardId), false)
            }
          }, (item: string) => item)
        } else if (this.selectedTabIndex === 1) {
          ForEach(this.viewModel.trendCardOrder, (cardId: TrendCard, index: number) => {
            GridItem() {
              this.SortItemCard(this.getTrendCardName(cardId), false)
            }
          }, (item: string) => item)
        }
      }
      .onAreaChange((oldArea, newArea) => {
        if (typeof newArea.width === 'number') {
          this.gridWidth = newArea.width;
        }
      })
      .width('100%')
      .height(
        (this.selectedTabIndex === 0
          ? this.viewModel.overviewCardOrder.length
          : this.viewModel.trendCardOrder.length) * 72 + 36
      )
      .padding({ left: 16, right: 16 })
      .columnsTemplate('1fr')
      .rowsGap(0)
      .editMode(true)
      .supportAnimation(true)

      .onItemDragStart((event, itemIndex) => {
        this.triggerVibration(); // 震动反馈
        return this.pixelMapBuilder(itemIndex);
      })

      .onItemDrop((event, itemIndex, insertIndex, isSuccess) => {
        // Grid 的 onItemDrop 只有在用户松手且位置有效时才会触发
        // 系统已经帮你处理完了“挤开”的视觉动画，这里我们只需要“确认数据”
        if (isSuccess && insertIndex !== -1 && itemIndex !== insertIndex) {

          this.triggerVibration(); // 成功放置震动

          if (this.selectedTabIndex === 0) {
            // 这里用原来的 onCardMove 即可，包含保存逻辑
            this.viewModel.onCardMove('OVERVIEW', itemIndex, insertIndex);
          } else {
            this.viewModel.onCardMove('TREND', itemIndex, insertIndex);
          }
        }
      })
    }
  }

  // --- 辅助函数 (保持不变) ---
  getOverviewCardName(id: OverviewCard): string {
    switch (id) {
      case OverviewCard.ACTIVE_STATS: return '今日概况';
      case OverviewCard.COMPLETION_TIME: return '完成时间分布';
      case OverviewCard.HISTORY_STATS: return '历史统计';
      default: return '未知卡片';
    }
  }

  getTrendCardName(id: TrendCard): string {
    switch (id) {
      case TrendCard.DAILY_TREND: return '本周完成情况';
      case TrendCard.MONTHLY_TREND: return '每月趋势';
      case TrendCard.WEEKLY_TREND: return '近4周完成';
      case TrendCard.CONTRIBUTION_HEATMAP: return '活跃热力图';
      default: return '未知卡片';
    }
  }
}
