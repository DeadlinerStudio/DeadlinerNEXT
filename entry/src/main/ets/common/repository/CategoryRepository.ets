import {
  CategoryDisplayModel,
  CategoryMutationInput,
  CategoryMutationResult,
  KmpCategoryRepositoryAdapter
} from '../kmp/KmpCategoryRepositoryAdapter';
import { KmpAutomaticSyncConfigurator } from '../kmp/KmpAutomaticSyncConfigurator';

/** HarmonyOS presentation gateway for the KMP-owned category catalog. */
export class CategoryRepository {
  private static instance: CategoryRepository;
  private readonly kmpCategories: KmpCategoryRepositoryAdapter = new KmpCategoryRepositoryAdapter();
  private cachedCategories: CategoryDisplayModel[] = [];
  private hasCachedCategories: boolean = false;

  private constructor() {}

  public static getInstance(): CategoryRepository {
    if (!CategoryRepository.instance) CategoryRepository.instance = new CategoryRepository();
    return CategoryRepository.instance;
  }

  public async listCategories(): Promise<CategoryDisplayModel[]> {
    try {
      const categories: CategoryDisplayModel[] = this.kmpCategories.listCategories();
      this.replaceCache(categories);
      return categories;
    } catch (error) {
      if (this.hasCachedCategories) return this.cachedCategories.concat();
      throw new Error('KMP category catalog unavailable: ' + String(error));
    }
  }

  public async createCategory(input: CategoryMutationInput): Promise<CategoryDisplayModel> {
    KmpAutomaticSyncConfigurator.getInstance().configure();
    const result: CategoryMutationResult = this.kmpCategories.createCategory(input);
    this.replaceCache(result.categories);
    if (result.category === null) throw new Error('KMP category creation did not return the category');
    return result.category;
  }

  public async updateCategory(input: CategoryMutationInput): Promise<CategoryDisplayModel> {
    KmpAutomaticSyncConfigurator.getInstance().configure();
    const result: CategoryMutationResult = this.kmpCategories.updateCategory(input);
    this.replaceCache(result.categories);
    if (result.category === null) throw new Error('KMP category update did not return the category');
    return result.category;
  }

  public async deleteCategory(uid: string): Promise<void> {
    KmpAutomaticSyncConfigurator.getInstance().configure();
    const result: CategoryMutationResult = this.kmpCategories.deleteCategory(uid, new Date().toISOString());
    this.replaceCache(result.categories);
  }

  public async restorePresets(): Promise<void> {
    KmpAutomaticSyncConfigurator.getInstance().configure();
    const result: CategoryMutationResult = this.kmpCategories.restorePresets();
    this.replaceCache(result.categories);
  }

  private replaceCache(categories: CategoryDisplayModel[]): void {
    this.cachedCategories = categories.concat();
    this.hasCachedCategories = true;
  }
}
