import { KmpPersistenceService } from './KmpPersistenceService';

export interface CategoryDisplayModel {
  uid: string;
  name: string;
  iconKey: string;
  colorHex: string;
  isPreset: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
  isDeleted: boolean;
}

export interface CategoryMutationInput {
  uid?: string;
  name: string;
  iconKey: string;
  colorHex: string;
}

export interface CategoryMutationResult {
  category: CategoryDisplayModel | null;
  categories: CategoryDisplayModel[];
}

/** Reads the KMP-owned category catalog without reimplementing category business rules in ArkTS. */
export class KmpCategoryRepositoryAdapter {
  private readonly persistence: KmpPersistenceService = KmpPersistenceService.getInstance();

  public listCategories(): CategoryDisplayModel[] {
    const payload: string = this.persistence.categoryCatalogJson();
    const categories: CategoryDisplayModel[] = JSON.parse(payload);
    return categories;
  }

  public createCategory(input: CategoryMutationInput): CategoryMutationResult {
    const payload: string = JSON.stringify(input);
    return this.parseMutationResult(this.persistence.categoryCreateJson(payload));
  }

  public updateCategory(input: CategoryMutationInput): CategoryMutationResult {
    const payload: string = JSON.stringify(input);
    return this.parseMutationResult(this.persistence.categoryUpdateJson(payload));
  }

  public deleteCategory(uid: string, updatedAt: string): CategoryMutationResult {
    return this.parseMutationResult(this.persistence.categoryDeleteJson(uid, updatedAt));
  }

  public restorePresets(): CategoryMutationResult {
    return this.parseMutationResult(this.persistence.categoryRestorePresetsJson());
  }

  private parseMutationResult(payload: string): CategoryMutationResult {
    const result: CategoryMutationResult = JSON.parse(payload);
    return result;
  }
}
