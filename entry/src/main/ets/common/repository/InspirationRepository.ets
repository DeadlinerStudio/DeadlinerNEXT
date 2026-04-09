import { DatabaseHelper } from '../data/DatabaseHelper';
import { InspirationItem } from '../../model/InspirationModels';

export class InspirationRepository {
  private static instance: InspirationRepository;
  private db: DatabaseHelper = DatabaseHelper.getInstance();

  public static getInstance(): InspirationRepository {
    if (!InspirationRepository.instance) {
      InspirationRepository.instance = new InspirationRepository();
    }
    return InspirationRepository.instance;
  }

  private async ensureDbReady(): Promise<void> {
    if (this.db.isReady()) {
      return;
    }

    const maxRetries = 40;
    for (let i = 0; i < maxRetries; i++) {
      if (this.db.isReady()) {
        return;
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }

    throw new Error('[InspirationRepository] DB Init Timeout.');
  }

  async getAllInspirations(): Promise<InspirationItem[]> {
    await this.ensureDbReady();
    return this.db.getAllInspirations();
  }

  async getInspirationById(id: number): Promise<InspirationItem | null> {
    await this.ensureDbReady();
    return this.db.getInspirationById(id);
  }

  async createInspiration(text: string): Promise<number> {
    await this.ensureDbReady();
    return this.db.insertInspiration(text);
  }

  async updateInspiration(item: InspirationItem): Promise<void> {
    await this.ensureDbReady();
    await this.db.updateInspiration(item);
  }

  async deleteInspiration(id: number): Promise<void> {
    await this.ensureDbReady();
    await this.db.deleteInspiration(id);
  }
}
