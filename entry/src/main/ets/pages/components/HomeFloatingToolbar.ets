import { HdsActionBar, ActionBarButton, ActionBarStyle, BlurStrategy } from '@kit.UIDesignKit'
import { ColorMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { SettingsConstants as C } from '../../common/local/SettingsConstants'
import { ITheme } from '../../common/theme/ThemeModel'
import {
  canUseSystemMaterial,
  DefaultFloatingToolbarMaterial,
  MaterialPresets
} from '../../common/style/SystemMaterialCompat'
import { IMMERSIVE_FLOATING_TOOLBAR_DEFAULT } from '../../common/local/ExperimentalComponentsPolicy'

@Component
export struct HomeFloatingToolbar {
  private readonly PRIMARY_BUTTON_SIZE: number = 56;
  private readonly SECONDARY_BUTTON_SIZE: number = 48;
  private readonly CAPSULE_THICKNESS: number = 52;
  private readonly ACTION_GAP: number = 4;
  private readonly CAPSULE_MAIN_AXIS_PADDING: number = 8;
  private readonly CAPSULE_CROSS_AXIS_PADDING: number = 2;
  private readonly TOOLBAR_RAISE_OFFSET: number = -20;
  private readonly TOOLBAR_ANIMATION_DURATION: number = 320;

  @StorageProp('currentTheme') theme: ITheme = {} as ITheme;

  @Require onClickAdd: () => void
  @Require handleBatchComplete: () => void
  @Require handleBatchArchive: () => void
  @Require handleBatchDelete: () => void
  @Require handleBatchEdit: () => void
  @Require handleSetAlarm: () => void

  isHorizontal: boolean = true

  @Prop isSelectionMode: boolean = false
  @Prop selectedTask: boolean = true;

  @StorageLink(C.KEY_ADD_SYMBOL_WEIGHT) addSymbolWeight: number = 600;
  @StorageLink(C.KEY_ENABLE_IMMERSIVE_FLOATING_TOOLBAR) immersiveFloatingToolbar: boolean =
    IMMERSIVE_FLOATING_TOOLBAR_DEFAULT;

  private getLeftButtonIcon(): Resource {
    if (this.selectedTask) {
      return $r('sys.symbol.checkmark_circle');
    }
    return $r('sys.symbol.alarm');
  }

  private onLeftButtonClick(): void {
    if (this.selectedTask) {
      this.handleBatchComplete();
      return;
    }
    this.handleSetAlarm();
  }

  private getCollapsedCapsuleScale(): number {
    const expandedLength: number = this.SECONDARY_BUTTON_SIZE * 4 + this.PRIMARY_BUTTON_SIZE +
      this.ACTION_GAP * 4 + this.CAPSULE_MAIN_AXIS_PADDING * 2;
    return this.PRIMARY_BUTTON_SIZE / expandedLength;
  }

  private getLegacyLeftButton(): ActionBarButton {
    if (this.selectedTask) {
      return new ActionBarButton({
        baseIcon: $r('sys.symbol.checkmark_circle'),
        onClick: () => this.handleBatchComplete()
      });
    }
    return new ActionBarButton({
      baseIcon: $r('sys.symbol.alarm'),
      onClick: () => this.handleSetAlarm()
    });
  }

  private getIconButtonWeighed(res: Resource, weight: number): SymbolGlyphModifier {
    return new SymbolGlyphModifier(res).fontWeight(weight);
  }

  @Builder
  private secondaryButton(icon: Resource, action: () => void) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([$r('app.color.font_primary')])
    }
    .type(ButtonType.Circle)
    .width(this.SECONDARY_BUTTON_SIZE)
    .height(this.SECONDARY_BUTTON_SIZE)
    .backgroundColor(Color.Transparent)
    .onClick(action)
  }

  @Builder
  private primaryButton() {
    Button() {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(28)
        .fontColor([Color.White])
        .fontWeight(this.addSymbolWeight)
        .rotate({ angle: this.isSelectionMode ? 45 : 0 })
        .animation({ duration: this.TOOLBAR_ANIMATION_DURATION, curve: Curve.Friction })
    }
    .type(ButtonType.Circle)
    .width(this.PRIMARY_BUTTON_SIZE)
    .height(this.PRIMARY_BUTTON_SIZE)
    .backgroundColor(this.theme.accent)
    .attributeModifier(MaterialPresets.surfaceGlowPreset(
      DefaultFloatingToolbarMaterial,
      true,
      this.theme.accent
    ))
    .onClick(this.onClickAdd)
  }

  @Builder
  private horizontalExpandedContent() {
    Row({ space: this.ACTION_GAP }) {
      this.secondaryButton(this.getLeftButtonIcon(), () => this.onLeftButtonClick())
      this.secondaryButton($r('sys.symbol.archivebox'), () => this.handleBatchArchive())
      Blank()
        .width(this.PRIMARY_BUTTON_SIZE)
        .height(this.SECONDARY_BUTTON_SIZE)
      this.secondaryButton($r('sys.symbol.square_and_pencil'), () => this.handleBatchEdit())
      this.secondaryButton($r('sys.symbol.trash'), () => this.handleBatchDelete())
    }
    .padding({
      left: this.CAPSULE_MAIN_AXIS_PADDING,
      right: this.CAPSULE_MAIN_AXIS_PADDING,
      top: this.CAPSULE_CROSS_AXIS_PADDING,
      bottom: this.CAPSULE_CROSS_AXIS_PADDING
    })
    .borderRadius(this.CAPSULE_THICKNESS / 2)
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(canUseSystemMaterial() ? BlurStyle.NONE : BlurStyle.Regular)
    .attributeModifier(MaterialPresets.surfaceGlowPreset(DefaultFloatingToolbarMaterial))
    .scale({ x: this.isSelectionMode ? 1 : this.getCollapsedCapsuleScale(), y: 1 })
    .opacity(this.isSelectionMode ? 1 : 0)
    .animation({ duration: this.TOOLBAR_ANIMATION_DURATION, curve: Curve.Friction })
    .hitTestBehavior(this.isSelectionMode ? HitTestMode.Transparent : HitTestMode.None)
  }

  @Builder
  private verticalExpandedContent() {
    Column({ space: this.ACTION_GAP }) {
      this.secondaryButton(this.getLeftButtonIcon(), () => this.onLeftButtonClick())
      this.secondaryButton($r('sys.symbol.archivebox'), () => this.handleBatchArchive())
      Blank()
        .width(this.SECONDARY_BUTTON_SIZE)
        .height(this.PRIMARY_BUTTON_SIZE)
      this.secondaryButton($r('sys.symbol.square_and_pencil'), () => this.handleBatchEdit())
      this.secondaryButton($r('sys.symbol.trash'), () => this.handleBatchDelete())
    }
    .padding({
      left: this.CAPSULE_CROSS_AXIS_PADDING,
      right: this.CAPSULE_CROSS_AXIS_PADDING,
      top: this.CAPSULE_MAIN_AXIS_PADDING,
      bottom: this.CAPSULE_MAIN_AXIS_PADDING
    })
    .borderRadius(this.CAPSULE_THICKNESS / 2)
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(canUseSystemMaterial() ? BlurStyle.NONE : BlurStyle.Regular)
    .attributeModifier(MaterialPresets.surfaceGlowPreset(DefaultFloatingToolbarMaterial))
    .transition(TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 1, y: this.getCollapsedCapsuleScale() }))
      .animation({ duration: this.TOOLBAR_ANIMATION_DURATION, curve: Curve.Friction }))
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private immersiveToolbar() {
    if (this.isHorizontal) {
      Stack({ alignContent: Alignment.Center }) {
        this.horizontalExpandedContent()
        this.primaryButton()
      }
      .translate({ y: this.TOOLBAR_RAISE_OFFSET })
      .animation({ duration: this.TOOLBAR_ANIMATION_DURATION, curve: Curve.Friction })
    } else {
      Stack({ alignContent: Alignment.Center }) {
        if (this.isSelectionMode) {
          this.verticalExpandedContent()
        }
        this.primaryButton()
      }
      .translate({ y: this.TOOLBAR_RAISE_OFFSET })
      .animation({ duration: this.TOOLBAR_ANIMATION_DURATION, curve: Curve.Friction })
    }
  }

  @Builder
  private legacyToolbar() {
    if (this.isHorizontal) {
      HdsActionBar({
        startButtons: [
          this.getLegacyLeftButton(),
          new ActionBarButton({
            baseIcon: $r('sys.symbol.archivebox'),
            onClick: () => this.handleBatchArchive()
          })
        ],
        primaryButton: new ActionBarButton({
          baseIconSymbolGlyphModifier: this.getIconButtonWeighed($r('sys.symbol.plus'), this.addSymbolWeight),
          altIconSymbolGlyphModifier: this.getIconButtonWeighed($r('sys.symbol.xmark'), this.addSymbolWeight),
          backgroundColor: ColorMetrics.resourceColor(this.theme.accent),
          onClick: () => this.onClickAdd()
        }),
        endButtons: [
          new ActionBarButton({
            baseIcon: $r('sys.symbol.square_and_pencil'),
            onClick: () => this.handleBatchEdit()
          }),
          new ActionBarButton({
            baseIcon: $r('sys.symbol.trash'),
            onClick: () => this.handleBatchDelete()
          })
        ],
        actionBarStyle: new ActionBarStyle({
          backgroundBlurStyle: BlurStyle.Regular,
          isPrimaryIconChanged: this.isSelectionMode
        }),
        blurStrategy: BlurStrategy.ENABLE,
        isExpand: this.isSelectionMode
      })
        .hitTestBehavior(HitTestMode.Transparent)
    } else {
      HdsActionBar({
        startButtons: [
          this.getLegacyLeftButton(),
          new ActionBarButton({
            baseIcon: $r('sys.symbol.archivebox'),
            onClick: () => this.handleBatchArchive()
          }),
          new ActionBarButton({
            baseIcon: $r('sys.symbol.square_and_pencil'),
            onClick: () => this.handleBatchEdit()
          }),
          new ActionBarButton({
            baseIcon: $r('sys.symbol.trash'),
            onClick: () => this.handleBatchDelete()
          })
        ],
        primaryButton: new ActionBarButton({
          baseIconSymbolGlyphModifier: this.getIconButtonWeighed($r('sys.symbol.plus'), this.addSymbolWeight),
          altIconSymbolGlyphModifier: this.getIconButtonWeighed($r('sys.symbol.xmark'), this.addSymbolWeight),
          backgroundColor: ColorMetrics.resourceColor(this.theme.accent),
          onClick: () => this.onClickAdd()
        }),
        actionBarStyle: new ActionBarStyle({
          backgroundBlurStyle: BlurStyle.Regular,
          isPrimaryIconChanged: this.isSelectionMode,
          isHorizontal: false
        }),
        blurStrategy: BlurStrategy.ENABLE,
        isExpand: this.isSelectionMode
      })
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  build() {
    if (this.immersiveFloatingToolbar) {
      this.immersiveToolbar()
    } else {
      this.legacyToolbar()
    }
  }
}
