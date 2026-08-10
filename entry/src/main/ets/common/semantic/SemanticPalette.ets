import { DeadlineSemanticStatus, SemanticTone } from './SemanticContract';
import { ITheme } from '../theme/ThemeModel';

export class SemanticPaletteToken {
  public readonly color: ResourceColor;

  constructor(color: ResourceColor) {
    this.color = color;
  }
}

export class SemanticPalette {
  public static forTone(tone: SemanticTone, theme: ITheme): SemanticPaletteToken {
    switch (tone) {
      case SemanticTone.SUCCESS:
        return SemanticPalette.success(theme);
      case SemanticTone.WARNING:
        return SemanticPalette.warning(theme);
      case SemanticTone.DANGER:
        return SemanticPalette.danger(theme);
      case SemanticTone.CALM:
        return SemanticPalette.calm(theme);
      case SemanticTone.NEUTRAL:
        return SemanticPalette.neutral();
      case SemanticTone.ACCENT:
      default:
        return SemanticPalette.accent(theme);
    }
  }

  public static forStatus(status: DeadlineSemanticStatus, theme: ITheme): SemanticPaletteToken {
    switch (status) {
      case DeadlineSemanticStatus.COMPLETED:
        return SemanticPalette.success(theme);
      case DeadlineSemanticStatus.NEAR_DUE:
        return SemanticPalette.warning(theme);
      case DeadlineSemanticStatus.OVERDUE:
        return SemanticPalette.danger(theme);
      case DeadlineSemanticStatus.ABANDONED:
        return SemanticPalette.neutral();
      case DeadlineSemanticStatus.ACTIVE:
      default:
        return SemanticPalette.accent(theme);
    }
  }

  private static accent(theme: ITheme): SemanticPaletteToken {
    return new SemanticPaletteToken(theme.indicatorUndergo);
  }

  private static success(theme: ITheme): SemanticPaletteToken {
    return new SemanticPaletteToken(theme.indicatorCompleted);
  }

  private static warning(theme: ITheme): SemanticPaletteToken {
    return new SemanticPaletteToken(theme.indicatorNear);
  }

  private static danger(theme: ITheme): SemanticPaletteToken {
    return new SemanticPaletteToken(theme.indicatorPassed);
  }

  private static calm(theme: ITheme): SemanticPaletteToken {
    return SemanticPalette.accent(theme);
  }

  private static neutral(): SemanticPaletteToken {
    return new SemanticPaletteToken($r('sys.color.ohos_id_color_text_tertiary'));
  }
}
