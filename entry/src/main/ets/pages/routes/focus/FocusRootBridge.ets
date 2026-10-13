import { KmpFocusTimerRepository } from '../../../common/kmp/KmpFocusTimerRepository';
import { FocusTimerUiStatePayload } from '../../../model/FocusModels';
import { FocusTimerSheet } from './FocusTimerSheet';
import { SheetCompat } from '../../../common/ui/SheetCompat';
import { FocusChangeConfirmation } from './FocusChangeConfirmation';

/** One root-owned reconciliation loop; HdsTabs owns the visible miniBar. */
@Component
export struct FocusRootBridge {
  @StorageLink('FocusConfirmationRevision') @Watch('onConfirmation') confirmationRevision: number = 0;
  private onConfirmation(): void { FocusChangeConfirmation.present(this.getUIContext()); }
  @StorageLink('FocusNotificationSessionUid') notificationSessionUid: string = '';
  @StorageLink('FocusTimerOpen') isShow: boolean = false;
  @StorageLink('IsAppDataReady') @Watch('refresh') dataReady: boolean = false;
  @StorageLink('FocusTimerRevision') @Watch('refresh') revision: number = 0;
  private interval: number = -1;
  private busy: boolean = false;
  private state: FocusTimerUiStatePayload | null = null;
  private loadedAt: number = 0;
  aboutToAppear(): void {
    this.refresh();
    this.interval = setInterval(() => {
      if (this.state?.timer !== null && this.state?.timer !== undefined) {
        const seconds: number | null = this.state.timer.remainingSeconds;
        if (Date.now() - this.loadedAt >= 15000 ||
          (seconds !== null && this.state.timer.state === 'RUNNING' && Date.now() - this.loadedAt >= seconds * 1000)) this.refresh();
      }
    }, 1000);
  }
  aboutToDisappear(): void { if (this.interval >= 0) clearInterval(this.interval); this.interval = -1; FocusChangeConfirmation.cancel(); }
  private async refresh(): Promise<void> {
    if (!this.dataReady || this.busy) return;
    this.busy = true;
    try {
      const hadActive: boolean = this.state?.timer !== null && this.state?.timer !== undefined;
      this.state = await KmpFocusTimerRepository.getInstance().state();
      if (hadActive && this.state.timer === null) {
        AppStorage.setOrCreate('FocusTimerRevision', (AppStorage.get<number>('FocusTimerRevision') ?? 0) + 1);
      }
      this.loadedAt = Date.now();
      AppStorage.setOrCreate('FocusTimerActive', this.state.timer !== null);
    } catch (_error) { }
    finally { this.busy = false; }
  }
  @Builder private sheet() { FocusTimerSheet({ isShow: $isShow, initialSessionUid: this.notificationSessionUid }) }
  build() {
    Column().width(0).height(0)
      .bindSheet($$this.isShow, this.sheet(), SheetCompat.immersive({
        height: SheetSize.LARGE, enableOutsideInteractive: false, showClose: true, dragBar: true,
        onDisappear: () => { this.isShow = false; this.notificationSessionUid = ''; this.refresh(); }
      }))
  }
}
