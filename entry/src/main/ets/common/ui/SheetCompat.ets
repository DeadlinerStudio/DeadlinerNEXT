import { Available } from '@kit.BasicServicesKit';
import { buildImmersiveMaterial, canUseSystemMaterial } from '../style/SystemMaterialCompat';

/**
 * Keeps the native Sheet appearance consistent across API levels.
 *
 * The immersive appearance is the default: API 26+ uses system material and
 * earlier API levels use the regular blur fallback. Use defaultBackground()
 * only when a sheet intentionally needs the platform's opaque background.
 */
export class SheetCompat {
  static immersive(
    options: SheetOptions,
    fallbackBlurStyle: BlurStyle = BlurStyle.Regular
  ): SheetOptions {
    options.backgroundColor = Color.Transparent;

    if (canUseSystemMaterial()) {
      return SheetCompat.applyImmersiveMaterial(options);
    }

    options.blurStyle = fallbackBlurStyle;
    return options;
  }

  static defaultBackground(options: SheetOptions): SheetOptions {
    options.blurStyle = BlurStyle.NONE;
    return options;
  }

  @Available({ minApiVersion: '26.0.0' })
  private static applyImmersiveMaterial(options: SheetOptions): SheetOptions {
    options.systemMaterial = buildImmersiveMaterial();
    return options;
  }
}
