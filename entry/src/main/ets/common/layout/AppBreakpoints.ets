export enum AppBreakpoint {
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

export const APP_BREAKPOINT_STORAGE_KEY: string = 'appBreakpoint';
export const APP_BREAKPOINT_DEFAULT: AppBreakpoint = AppBreakpoint.MD;

export const APP_BREAKPOINT_ORDER: AppBreakpoint[] = [
  AppBreakpoint.SM,
  AppBreakpoint.MD,
  AppBreakpoint.LG,
  AppBreakpoint.XL
];

export class AppBreakpointUtils {
  static readonly MD_MIN_WIDTH: number = 600;
  static readonly LG_MIN_WIDTH: number = 840;
  static readonly XL_MIN_WIDTH: number = 1320;

  static mediaCondition(breakpoint: AppBreakpoint): string {
    switch (breakpoint) {
      case AppBreakpoint.SM:
        return `(width<${AppBreakpointUtils.MD_MIN_WIDTH}vp)`;
      case AppBreakpoint.MD:
        return `(${AppBreakpointUtils.MD_MIN_WIDTH}vp<=width<${AppBreakpointUtils.LG_MIN_WIDTH}vp)`;
      case AppBreakpoint.LG:
        return `(${AppBreakpointUtils.LG_MIN_WIDTH}vp<=width<${AppBreakpointUtils.XL_MIN_WIDTH}vp)`;
      case AppBreakpoint.XL:
        return `(${AppBreakpointUtils.XL_MIN_WIDTH}vp<=width)`;
      default:
        return `(${AppBreakpointUtils.MD_MIN_WIDTH}vp<=width<${AppBreakpointUtils.LG_MIN_WIDTH}vp)`;
    }
  }

  static fromWidthVp(widthVp: number): AppBreakpoint {
    if (widthVp >= AppBreakpointUtils.XL_MIN_WIDTH) {
      return AppBreakpoint.XL;
    }
    if (widthVp >= AppBreakpointUtils.LG_MIN_WIDTH) {
      return AppBreakpoint.LG;
    }
    if (widthVp >= AppBreakpointUtils.MD_MIN_WIDTH) {
      return AppBreakpoint.MD;
    }
    return AppBreakpoint.SM;
  }

  static isWide(breakpoint: string): boolean {
    return breakpoint === AppBreakpoint.LG || breakpoint === AppBreakpoint.XL;
  }
}
