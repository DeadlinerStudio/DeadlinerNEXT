import { CategoryDisplayModel } from '../kmp/KmpCategoryRepositoryAdapter';

export enum CategoryFilterMode {
  ALL = 'all',
  UNCATEGORIZED = 'uncategorized',
  SELECTED = 'selected'
}

/** Immutable value carried from the SideBar to task and habit projections. */
export class CategoryFilter {
  readonly mode: CategoryFilterMode;
  readonly categoryUids: string[];
  readonly isUncategorizedSelected: boolean;

  constructor(
    mode: CategoryFilterMode = CategoryFilterMode.ALL,
    categoryUids: string[] = [],
    isUncategorizedSelected: boolean = false
  ) {
    this.mode = mode;
    this.categoryUids = categoryUids.concat();
    this.isUncategorizedSelected = isUncategorizedSelected;
  }

  public static all(): CategoryFilter {
    return new CategoryFilter(CategoryFilterMode.ALL);
  }

  public static uncategorized(): CategoryFilter {
    return CategoryFilter.selected([], true);
  }

  public static selected(categoryUids: string[], isUncategorizedSelected: boolean = false): CategoryFilter {
    return categoryUids.length === 0 && !isUncategorizedSelected
      ? CategoryFilter.all()
      : new CategoryFilter(CategoryFilterMode.SELECTED, categoryUids, isUncategorizedSelected);
  }
}

export class CategoryFilterResolver {
  public static matches(
    filter: CategoryFilter,
    categoryUid: string | null | undefined,
    categories: CategoryDisplayModel[]
  ): boolean {
    if (filter.mode === CategoryFilterMode.ALL) return true;
    if (filter.mode === CategoryFilterMode.UNCATEGORIZED) {
      return CategoryFilterResolver.isUncategorized(categoryUid, categories);
    }
    if (filter.mode === CategoryFilterMode.SELECTED) {
      if (categoryUid === null || categoryUid === undefined || categoryUid.length === 0) {
        return filter.isUncategorizedSelected;
      }
      if (!CategoryFilterResolver.isAvailable(categoryUid, categories)) {
        return filter.isUncategorizedSelected;
      }
      return filter.categoryUids.indexOf(categoryUid) >= 0;
    }
    return false;
  }

  private static isUncategorized(uid: string | null | undefined, categories: CategoryDisplayModel[]): boolean {
    if (uid === null || uid === undefined || uid.length === 0) return true;
    return !CategoryFilterResolver.isAvailable(uid, categories);
  }

  private static isAvailable(uid: string | null | undefined, categories: CategoryDisplayModel[]): boolean {
    if (uid === null || uid === undefined || uid.length === 0) return false;
    for (let index = 0; index < categories.length; index += 1) {
      if (categories[index].uid === uid) return true;
    }
    return false;
  }
}
