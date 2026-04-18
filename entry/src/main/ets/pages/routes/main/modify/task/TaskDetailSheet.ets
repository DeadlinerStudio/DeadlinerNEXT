import { promptAction } from '@kit.ArkUI';
import { ITheme } from '../../../../../common/theme/ThemeModel';
import { DDLItem, SubTask } from '../../../../../model/DDLModels';
import { TaskRepository } from '../../../../../common/repository/TaskRepository';
import { DateTimeUtils } from '../../../../../utils/DateTimeUtils';
import { TaskStateMachine } from '../../../../../model/TaskStateMachine';
import { TaskEditSheet } from './TaskEditSheet';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';

@Component
struct TaskDetailSubTaskRow {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Prop item: SubTask;
  @Prop disabled: boolean = false;
  onToggle: (item: SubTask) => void = () => {};
  onDelete: (item: SubTask) => void = () => {};
  onLongPressEdit: (item: SubTask) => void = () => {};

  build() {
    Row({ space: 10 }) {
      Checkbox({ name: `sub_${this.item.id}`, group: 'task_detail_subtask_group' })
        .select(this.item.isCompleted)
        .selectedColor(this.theme.accent)
        .onChange(() => {
          this.onToggle(this.item);
        })
        .enabled(!this.disabled)
        .margin({ right: 2 })

      Text(this.item.content)
        .fontSize(14)
        .fontColor(this.item.isCompleted ? $r('sys.color.ohos_id_color_text_tertiary') : $r('sys.color.ohos_id_color_text_primary'))
        .decoration({ type: this.item.isCompleted ? TextDecorationType.LineThrough : TextDecorationType.None })
        .layoutWeight(1)
        .maxLines(3)

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.trash'))
          .fontSize(16)
          .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
      }
      .width(28)
      .height(28)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onDelete(this.item);
      })
      .enabled(!this.disabled)
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 9, bottom: 9 })
    .backgroundColor($r('app.color.background_secondary'))
    .borderRadius(14)
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (!this.disabled) {
            this.onLongPressEdit(this.item);
          }
        })
    )
  }
}

@Component
export struct TaskDetailSheet {
  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Link @Watch('onShowChange') isShow: boolean;
  @Prop task: DDLItem | null;
  onTaskChanged: () => Promise<void> = async () => {};

  private readonly PLAN_COMPOSER_INPUT_ID: string = 'task_detail_plan_composer_input';

  @State private currentTask: DDLItem | null = null;
  @State private subTasks: SubTask[] = [];
  @State private subTaskRenderVersion: number = 0;
  @State private isPlanLoading: boolean = false;
  @State private isMutatingPlan: boolean = false;

  @State private showPlanComposer: boolean = false;
  @State private draftSubTask: string = '';
  @State private ignoreBlurSubmit: boolean = false;

  @State private editingSubTaskId: number = -1;
  @State private editingSubTaskDraft: string = '';
  @State private ignoreEditBlurSubmit: boolean = false;

  @State private animatedProgress: number = 0;
  @State private isSavingStar: boolean = false;

  @State private isEditSheetShow: boolean = false;
  @State private editingTask: DDLItem | null = null;

  private repo = TaskRepository.getInstance();

  private normalizeSubTasks(raw: SubTask[] | undefined | null): SubTask[] {
    if (!raw || !Array.isArray(raw)) {
      return [];
    }
    return raw;
  }

  private cloneTask(task: DDLItem): DDLItem {
    return {
      id: task.id,
      name: task.name,
      startTime: task.startTime,
      endTime: task.endTime,
      state: task.state,
      isCompleted: task.isCompleted,
      completeTime: task.completeTime,
      note: task.note,
      isArchived: task.isArchived,
      isStared: task.isStared,
      type: task.type,
      habitCount: task.habitCount,
      habitTotalCount: task.habitTotalCount,
      calendarEventId: task.calendarEventId,
      timeStamp: task.timeStamp,
      uid: task.uid,
      deleted: task.deleted,
      verTs: task.verTs,
      verCtr: task.verCtr,
      verDev: task.verDev
    };
  }

  private bumpSubTaskRenderVersion() {
    this.subTaskRenderVersion += 1;
  }

  aboutToAppear(): void {
    this.loadDetail();
  }

  private onShowChange() {
    if (this.isShow) {
      this.loadDetail();
    }
  }

  private async loadDetail() {
    if (!this.isShow || !this.task) return;

    try {
      const latest = await this.repo.getDDLById(this.task.id);
      const nextTask = latest ?? this.task;
      this.currentTask = this.cloneTask(nextTask);
      await this.loadSubTasks(nextTask.id);
      this.animateProgressIn();
    } catch (e) {
      console.error(`[TaskDetailSheet] loadDetail failed: ${e}`);
      promptAction.showToast({ message: '加载任务详情失败' });
    }
  }

  private async loadSubTasks(taskId: number) {
    this.isPlanLoading = true;
    try {
      const loaded = await this.repo.getSubTasks(taskId);
      this.subTasks = this.normalizeSubTasks(loaded);
      this.bumpSubTaskRenderVersion();
    } catch (e) {
      console.error(`[TaskDetailSheet] loadSubTasks failed: ${e}`);
      this.subTasks = [];
      this.bumpSubTaskRenderVersion();
      promptAction.showToast({ message: '加载子任务失败' });
    } finally {
      this.isPlanLoading = false;
    }
  }

  private getDisplayedSubTasksSafe(): SubTask[] {
    try {
      const safe = this.normalizeSubTasks(this.subTasks);
      const copied = safe.slice();
      copied.sort((lhs, rhs) => {
        if (lhs.isCompleted !== rhs.isCompleted) {
          return lhs.isCompleted ? 1 : -1;
        }
        if (lhs.sortOrder !== rhs.sortOrder) {
          return lhs.sortOrder - rhs.sortOrder;
        }
        return lhs.id - rhs.id;
      });
      return copied;
    } catch (e) {
      console.error(`[TaskDetailSheet] getDisplayedSubTasksSafe failed: ${e}`);
      return [];
    }
  }

  private getDisplayedSubTaskCount(): number {
    const safe = this.getDisplayedSubTasksSafe();
    return safe ? safe.length : 0;
  }

  private getProgressSubtitle(): string {
    if (!this.currentTask) return '当前任务时间进度';
    if (this.currentTask.isCompleted) return '任务已完成';
    if (TaskStateMachine.isAbandonedLike(this.currentTask.state)) return '任务已放弃';
    return '当前任务时间进度';
  }

  private getNoteText(): string {
    const raw = this.currentTask ? this.currentTask.note : '';
    const note = typeof raw === 'string' ? raw : '';
    const trimmed = note.trim();
    return trimmed.length > 0 ? note : '无备注';
  }

  private getPlanSummaryText(): string {
    const all = this.normalizeSubTasks(this.subTasks);
    const total = all.length;
    const completed = all.filter((item) => item.isCompleted).length;
    if (total === 0) {
      return '还没有子任务';
    }
    return `已完成 ${completed} / ${total}`;
  }

  private calculateProgress(task: DDLItem): number {
    const start = DateTimeUtils.parseDateString(task.startTime);
    const end = DateTimeUtils.parseDateString(task.endTime);

    if (!start || !end || end.getTime() <= start.getTime()) {
      return task.isCompleted ? 1 : 0;
    }

    if (task.isCompleted) return 1;

    const now = Date.now();
    if (now <= start.getTime()) return 0;
    if (now >= end.getTime()) return 1;

    return (now - start.getTime()) / (end.getTime() - start.getTime());
  }

  private animateProgressIn() {
    const task = this.currentTask;
    if (!task) return;

    const target = Math.max(0, Math.min(1, this.calculateProgress(task)));
    this.animatedProgress = 0;
    setTimeout(() => {
      animateTo({ duration: 900, curve: Curve.EaseInOut }, () => {
        this.animatedProgress = target;
      });
    }, 80);
  }

  private formatTaskTime(raw: string): string {
    const date = DateTimeUtils.parseDateString(raw);
    return date ? DateTimeUtils.formatForUI(date) : (raw || '未设置');
  }

  private async toggleStar() {
    if (!this.currentTask || this.isSavingStar) return;

    this.isSavingStar = true;
    const oldStar = this.currentTask.isStared;
    const nextTask = this.cloneTask(this.currentTask);
    nextTask.isStared = !oldStar;
    this.currentTask = nextTask;

    try {
      await this.repo.updateDDL(this.currentTask);
      await this.onTaskChanged();
    } catch (e) {
      console.error(`[TaskDetailSheet] toggleStar failed: ${e}`);
      if (this.currentTask) {
        const rollbackTask = this.cloneTask(this.currentTask);
        rollbackTask.isStared = oldStar;
        this.currentTask = rollbackTask;
      }
      promptAction.showToast({ message: '星标更新失败' });
    } finally {
      this.isSavingStar = false;
    }
  }

  private openEditSheet() {
    if (!this.currentTask) return;
    this.editingTask = this.cloneTask(this.currentTask);
    this.isEditSheetShow = true;
  }

  private async onEditSaved(task: DDLItem) {
    await this.repo.updateDDL(task);
    await this.loadDetail();
    await this.onTaskChanged();
  }

  private showComposerAndFocus() {
    this.editingSubTaskId = -1;
    this.showPlanComposer = true;
    setTimeout(() => {
      focusControl.requestFocus(this.PLAN_COMPOSER_INPUT_ID);
    }, 100);
  }

  private onComposerSubmit() {
    this.ignoreBlurSubmit = true;
    this.submitSubTask(true);
    setTimeout(() => {
      this.ignoreBlurSubmit = false;
    }, 220);
  }

  private enterInlineEdit(subTask: SubTask) {
    this.showPlanComposer = false;
    this.editingSubTaskId = subTask.id;
    this.editingSubTaskDraft = subTask.content;
  }

  private onInlineEditSubmit() {
    this.ignoreEditBlurSubmit = true;
    this.submitInlineEdit(true);
    setTimeout(() => {
      this.ignoreEditBlurSubmit = false;
    }, 220);
  }

  private async submitInlineEdit(keepEditing: boolean) {
    if (this.isMutatingPlan || !this.currentTask || this.editingSubTaskId < 0) return;

    const id = this.editingSubTaskId;
    const nextContent = this.editingSubTaskDraft.trim();
    const index = this.subTasks.findIndex((item) => item.id === id);
    if (index < 0) {
      this.editingSubTaskId = -1;
      return;
    }

    if (!nextContent) {
      if (!keepEditing) {
        this.editingSubTaskId = -1;
      }
      return;
    }

    const source = this.subTasks[index];
    if (source.content === nextContent) {
      if (!keepEditing) {
        this.editingSubTaskId = -1;
      }
      return;
    }

    this.isMutatingPlan = true;
    const optimistic: SubTask = {
      id: source.id,
      ddlId: source.ddlId,
      content: nextContent,
      isCompleted: source.isCompleted,
      sortOrder: source.sortOrder,
      uid: source.uid,
      deleted: source.deleted,
      verTs: source.verTs,
      verCtr: source.verCtr,
      verDev: source.verDev
    };
    this.subTasks[index] = optimistic;
    this.subTasks = this.subTasks.slice();
    this.bumpSubTaskRenderVersion();

    try {
      await this.repo.updateSubTaskContent(source.id, nextContent);
      await this.onTaskChanged();
      if (!keepEditing) {
        this.editingSubTaskId = -1;
      }
    } catch (e) {
      console.error(`[TaskDetailSheet] submitInlineEdit failed: ${e}`);
      this.subTasks[index] = source;
      this.subTasks = this.subTasks.slice();
      this.bumpSubTaskRenderVersion();
      promptAction.showToast({ message: '更新子任务失败' });
    } finally {
      this.isMutatingPlan = false;
    }
  }

  private async submitSubTask(keepComposerVisible: boolean) {
    if (this.isMutatingPlan || !this.currentTask) return;

    const content = this.draftSubTask.trim();
    if (!content) {
      if (!keepComposerVisible) {
        this.showPlanComposer = false;
      }
      return;
    }

    this.isMutatingPlan = true;
    this.draftSubTask = '';

    try {
      const nextSortOrder = this.subTasks
        .map((item) => item.sortOrder)
        .reduce((acc, cur) => Math.max(acc, cur), -1) + 1;
      await this.repo.insertSubTask(this.currentTask.id, content, nextSortOrder);
      await this.loadSubTasks(this.currentTask.id);
      await this.onTaskChanged();

      if (keepComposerVisible) {
        setTimeout(() => {
          focusControl.requestFocus(this.PLAN_COMPOSER_INPUT_ID);
        }, 80);
      } else {
        this.showPlanComposer = false;
      }
    } catch (e) {
      console.error(`[TaskDetailSheet] submitSubTask failed: ${e}`);
      promptAction.showToast({ message: '新增子任务失败' });
    } finally {
      this.isMutatingPlan = false;
    }
  }

  private async toggleSubTask(subTask: SubTask) {
    if (this.isMutatingPlan || !this.currentTask) return;

    this.isMutatingPlan = true;
    const index = this.subTasks.findIndex((item) => item.id === subTask.id);
    if (index < 0) {
      this.isMutatingPlan = false;
      return;
    }

    const source = this.subTasks[index];
    const optimistic: SubTask = {
      id: source.id,
      ddlId: source.ddlId,
      content: source.content,
      isCompleted: !source.isCompleted,
      sortOrder: source.sortOrder,
      uid: source.uid,
      deleted: source.deleted,
      verTs: source.verTs,
      verCtr: source.verCtr,
      verDev: source.verDev
    };

    // 先本地更新，确保点击后立即有视觉反馈
    this.subTasks[index] = optimistic;
    this.subTasks = this.subTasks.slice();
    this.bumpSubTaskRenderVersion();

    try {
      await this.repo.toggleSubTask(source);
      await this.onTaskChanged();
    } catch (e) {
      console.error(`[TaskDetailSheet] toggleSubTask failed: ${e}`);
      // 失败回滚
      this.subTasks[index] = source;
      this.subTasks = this.subTasks.slice();
      this.bumpSubTaskRenderVersion();
      promptAction.showToast({ message: '更新子任务失败' });
    } finally {
      this.isMutatingPlan = false;
    }
  }

  private async deleteSubTask(subTask: SubTask) {
    if (this.isMutatingPlan || !this.currentTask) return;

    this.isMutatingPlan = true;
    try {
      await this.repo.deleteSubTask(subTask.id);
      this.subTasks = this.subTasks.filter((item) => item.id !== subTask.id);
      this.bumpSubTaskRenderVersion();
      await this.onTaskChanged();
    } catch (e) {
      console.error(`[TaskDetailSheet] deleteSubTask failed: ${e}`);
      promptAction.showToast({ message: '删除子任务失败' });
    } finally {
      this.isMutatingPlan = false;
    }
  }

  @Builder
  private taskEditSheet() {
    TaskEditSheet({
      isShow: $isEditSheetShow,
      editingTask: this.editingTask,
      onSave: async (task: DDLItem): Promise<void> => {
        await this.onEditSaved(task);
      }
    })
  }

  build() {
    HdsNavigation() {
      if (!this.currentTask) {
        Column() {
          LoadingProgress().width(42).height(42)
          Text('正在加载任务详情')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .margin({ top: 10 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 10 }) {
              Row({ space: 10 }) {
                Text(`${Math.round(this.animatedProgress * 100)}%`)
                  .fontSize(38)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)

                Text(this.getProgressSubtitle())
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
              }
              .width('100%')

              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .width('100%')
                  .height(12)
                  .backgroundColor($r('app.color.background_tertiary'))
                  .borderRadius(10)

                Row()
                  .width(`${Math.max(0, Math.min(1, this.animatedProgress)) * 100}%`)
                  .height(12)
                  .linearGradient({
                    direction: GradientDirection.Right,
                    colors: [
                      [this.theme.brand50, 0.0],
                      [this.theme.accent, 1.0]
                    ]
                  })
                  .borderRadius(10)
              }
              .width('100%')
              .height(12)
            }
            .width('100%')
            .padding(18)
            .backgroundColor($r('sys.color.search_container_focus_color'))
            .borderRadius(24)

            Column({ space: 12 }) {
              Text(this.currentTask.name)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .width('100%')

              Divider()

              Row() {
                Text('开始')
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                Blank().layoutWeight(1)
                Text(this.formatTaskTime(this.currentTask.startTime))
                  .fontSize(14)
              }
              .width('100%')

              Row() {
                Text('截止')
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                Blank().layoutWeight(1)
                Text(this.formatTaskTime(this.currentTask.endTime))
                  .fontSize(14)
              }
              .width('100%')
            }
            .width('100%')
            .padding(18)
            .backgroundColor($r('sys.color.search_container_focus_color'))
            .borderRadius(24)

            Column({ space: 8 }) {
              Text('任务备注')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .width('100%')

              Text(this.getNoteText())
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .opacity(0.88)
                .width('100%')
                .maxLines(8)
            }
            .width('100%')
            .padding(18)
            .backgroundColor($r('sys.color.search_container_focus_color'))
            .borderRadius(24)

            Column({ space: 12 }) {
              Row() {
                Text('详细计划')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                Blank().layoutWeight(1)
                Text(this.getPlanSummaryText())
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .width('100%')

              if (this.isPlanLoading && this.getDisplayedSubTaskCount() === 0) {
                Row({ space: 8 }) {
                  LoadingProgress().width(18).height(18)
                  Text('正在加载子任务')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .width('100%')
              } else if (this.getDisplayedSubTaskCount() === 0) {
                Text('点击右上角菜单中的 + 添加第一条子任务')
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .width('100%')
              } else {
                Column({ space: 8 }) {
                  ForEach(this.getDisplayedSubTasksSafe(), (item: SubTask) => {
                    if (this.editingSubTaskId === item.id) {
                      Row({ space: 10 }) {
                        Checkbox({ name: `sub_${item.id}`, group: 'task_detail_subtask_group' })
                          .select(item.isCompleted)
                          .selectedColor(this.theme.accent)
                          .enabled(false)
                          .margin({ right: 2 })

                        TextInput({ text: $$this.editingSubTaskDraft, placeholder: '输入子任务内容' })
                          .fontSize(14)
                          .maxLines(3)
                          .layoutWeight(1)
                          .backgroundColor(Color.Transparent)
                          .enterKeyType(EnterKeyType.Done)
                          .onSubmit(() => {
                            this.onInlineEditSubmit();
                          })
                          .onBlur(() => {
                            if (this.ignoreEditBlurSubmit) return;
                            this.submitInlineEdit(false);
                          })
                          .enabled(!this.isMutatingPlan)

                        Button({ type: ButtonType.Circle, stateEffect: true }) {
                          SymbolGlyph($r('sys.symbol.xmark'))
                            .fontSize(16)
                            .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                        }
                        .width(28)
                        .height(28)
                        .backgroundColor(Color.Transparent)
                        .onClick(() => {
                          this.editingSubTaskId = -1;
                        })
                      }
                      .width('100%')
                      .padding({ left: 10, right: 10, top: 2, bottom: 2 })
                      .backgroundColor($r('app.color.background_secondary'))
                      .borderRadius(14)
                    } else {
                      TaskDetailSubTaskRow({
                        item: item,
                        disabled: this.isMutatingPlan,
                        onToggle: (target: SubTask) => {
                          this.toggleSubTask(target);
                        },
                        onDelete: (target: SubTask) => {
                          this.deleteSubTask(target);
                        },
                        onLongPressEdit: (target: SubTask) => {
                          this.enterInlineEdit(target);
                        }
                      })
                    }
                  }, (item: SubTask) => `${item.id}_${item.isCompleted ? 1 : 0}_${this.subTaskRenderVersion}`)
                }
                .width('100%')
              }

              if (this.showPlanComposer) {
                Row({ space: 10 }) {
                  Checkbox({ name: 'task_detail_new_subtask', group: 'task_detail_subtask_group' })
                    .select(false)
                    .selectedColor(this.theme.accent)
                    .enabled(false)
                    .margin({ right: 2 })

                  TextInput({ text: $$this.draftSubTask, placeholder: '输入子任务内容' })
                    .id(this.PLAN_COMPOSER_INPUT_ID)
                    .fontSize(14)
                    .maxLines(3)
                    .layoutWeight(1)
                    .backgroundColor(Color.Transparent)
                    .enterKeyType(EnterKeyType.Done)
                    .onSubmit(() => {
                      this.onComposerSubmit();
                    })
                    .onBlur(() => {
                      if (this.ignoreBlurSubmit) return;
                      this.submitSubTask(false);
                    })
                    .enabled(!this.isMutatingPlan)

                  Button({ type: ButtonType.Circle, stateEffect: true }) {
                    SymbolGlyph($r('sys.symbol.xmark'))
                      .fontSize(16)
                      .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }
                  .width(28)
                  .height(28)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    this.showPlanComposer = false;
                    this.draftSubTask = '';
                  })
                }
                .width('100%')
                .padding({ left: 10, right: 10, top: 9, bottom: 9 })
                .backgroundColor($r('app.color.background_secondary'))
                .borderRadius(14)
              }
            }
            .width('100%')
            .padding(18)
            .backgroundColor($r('sys.color.search_container_focus_color'))
            .borderRadius(24)

            Blank().height(24)
          }
          .width('100%')
          .padding({ top: 64, left: 16, right: 16 })
          .justifyContent(FlexAlign.Start)
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
      }
    }
    .titleBar({
      content: {
        title: {
          mainTitle: '任务详情'
        },
        menu: {
          value: [
            { content: { icon: $r('sys.symbol.plus'), action: () => this.showComposerAndFocus() } },
            {
              content: {
                icon: this.currentTask && this.currentTask.isStared ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
                action: async () => this.toggleStar()
              }
            },
            { content: { icon: $r('sys.symbol.square_and_pencil'), action: () => this.openEditSheet() } }
          ]
        },
        subIcon: {
          content: {
            icon: $r('sys.symbol.xmark'),
            action: () => {
              this.isShow = false;
            }
          }
        }
      },
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .hideBackButton(false)
    .backgroundColor(Color.Transparent)
    .width('100%')
    .height('100%')
    .bindSheet($$this.isEditSheetShow, this.taskEditSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      onDisappear: () => {
        this.isEditSheetShow = false;
        this.editingTask = null;
      },
      blurStyle: BlurStyle.Regular,
      backgroundColor: Color.Transparent,
      title: {
        title: '编辑任务',
        subtitle: '修改任务信息。'
      }
    })
  }
}
