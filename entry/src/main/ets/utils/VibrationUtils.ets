import { LocalValues } from "../common/local/LocalValues"
import { vibrator } from "@kit.SensorServiceKit"
import { AppLog } from '../common/logging/AppLog';

export class VibrationUtils {
  private static assureVibrationEnable(): boolean {
    AppLog.debug('Native', '[Vibration] ' + LocalValues.getInstance().getVibration())
    return LocalValues.getInstance().getVibration()
  }

  public static vibrateShort() {
    if (VibrationUtils.assureVibrationEnable()) {
      vibrator.startVibration({
        type: "time",
        duration: 50
      }, {
        usage: "communication"
      })
    }
  }

  public static vibrateMedium() {
    if (VibrationUtils.assureVibrationEnable()) {
      vibrator.startVibration({
        type: "time",
        duration: 100
      }, {
        usage: "communication"
      })
    }
  }

  public static vibrateTouch() {
    if (VibrationUtils.assureVibrationEnable()) {
      vibrator.startVibration({ type: 'time', duration: 15 }, { id: 0, usage: 'touch' });
    }
  }

  public static vibrateSoft() {
    if (VibrationUtils.assureVibrationEnable()) {
      vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' })
    }
  }
}
