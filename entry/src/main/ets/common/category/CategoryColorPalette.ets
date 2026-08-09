/** Cross-platform category color contract from the iOS category picker. */
export class CategoryColorOption {
  public readonly token: string;
  public readonly hex: string;

  public constructor(token: string, hex: string) {
    this.token = token;
    this.hex = hex;
  }
}

export class CategoryColorPalette {
  private static readonly options: CategoryColorOption[] = [
    new CategoryColorOption('blue_500', '#3B82F6'),
    new CategoryColorOption('blue_600', '#2563EB'),
    new CategoryColorOption('indigo_500', '#6366F1'),
    new CategoryColorOption('violet_500', '#8B5CF6'),
    new CategoryColorOption('purple_500', '#A855F7'),
    new CategoryColorOption('pink_500', '#EC4899'),
    new CategoryColorOption('rose_500', '#F43F5E'),
    new CategoryColorOption('red_500', '#EF4444'),
    new CategoryColorOption('orange_500', '#F97316'),
    new CategoryColorOption('amber_500', '#F59E0B'),
    new CategoryColorOption('yellow_500', '#EAB308'),
    new CategoryColorOption('lime_500', '#84CC16'),
    new CategoryColorOption('green_500', '#22C55E'),
    new CategoryColorOption('emerald_500', '#10B981'),
    new CategoryColorOption('teal_500', '#14B8A6'),
    new CategoryColorOption('cyan_500', '#06B6D4'),
    new CategoryColorOption('sky_500', '#0EA5E9'),
    new CategoryColorOption('slate_500', '#64748B'),
    new CategoryColorOption('gray_500', '#8E8E93'),
    new CategoryColorOption('gray_900', '#111827')
  ];

  public static all(): CategoryColorOption[] {
    return CategoryColorPalette.options.concat();
  }
}
