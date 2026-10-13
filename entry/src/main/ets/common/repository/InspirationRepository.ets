import { InspirationItem } from '../../model/InspirationModels';
import { common } from '@kit.AbilityKit';
import { KmpCaptureRepositoryAdapter } from '../kmp/KmpCaptureRepositoryAdapter';
import { KmpMigrationService } from '../migration/KmpMigrationService';
import { KmpAutomaticSyncConfigurator } from '../kmp/KmpAutomaticSyncConfigurator';

export class InspirationRepository {
  private static instance: InspirationRepository;
  private context: common.Context | null = null;
  private readonly kmpCapture: KmpCaptureRepositoryAdapter = new KmpCaptureRepositoryAdapter();

  public static getInstance(): InspirationRepository {
    if (!InspirationRepository.instance) {
      InspirationRepository.instance = new InspirationRepository();
    }
    return InspirationRepository.instance;
  }

  public setContext(context: common.Context): void { this.context = context; }

  async getAllInspirations(): Promise<InspirationItem[]> {
    await this.usesKmpCapture();
    return this.kmpCapture.list();
  }

  async getInspirationById(id: number): Promise<InspirationItem | null> {
    await this.usesKmpCapture();
    return this.kmpCapture.find(id);
  }

  async createInspiration(text: string): Promise<number> {
    await this.usesKmpCapture();
    return this.kmpCapture.create(text);
  }

  async updateInspiration(item: InspirationItem): Promise<void> {
    await this.usesKmpCapture();
    await this.kmpCapture.update(item);
  }

  async deleteInspiration(id: number): Promise<void> {
    await this.usesKmpCapture();
    await this.kmpCapture.delete(id);
  }

  private async usesKmpCapture(): Promise<boolean> {
    if (this.context === null) throw new Error('InspirationRepository context is required for KMP persistence');
    await KmpMigrationService.getInstance().awaitReady();
    await this.kmpCapture.initialize(this.context);
    KmpAutomaticSyncConfigurator.getInstance().configure();
    return true;
  }
}
