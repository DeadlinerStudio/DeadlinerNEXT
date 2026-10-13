import { describe, it, expect } from '@ohos/hypium';
import { FocusPresentation } from '../main/ets/pages/routes/focus/FocusPresentation';
export default function focusPresentationTests(): void {
  describe('FocusPresentation', () => {
    it('clockIsBounded', 0, () => {
      expect(FocusPresentation.clock(-1)).assertEqual('00:00');
      expect(FocusPresentation.clock(3661)).assertEqual('1:01:01');
      expect(FocusPresentation.clock(61)).assertEqual('01:01');
    });
    it('durationsRemainSeconds', 0, () => {
      expect(FocusPresentation.duration(59)).assertEqual('59 秒');
      expect(FocusPresentation.duration(1200)).assertEqual('20 分钟');
      expect(FocusPresentation.duration(3600)).assertEqual('1 小时 0 分');
    });
    it('nonDueDoesNotPromiseCheckIn', 0, () => {
      expect(FocusPresentation.outcome('HABIT_NOT_DUE').includes('不能打卡')).assertTrue();
      expect(FocusPresentation.outcome('INVALID_STATE').includes('取消')).assertTrue();
      expect(FocusPresentation.outcome('APPLIED')).assertEqual('');
    });
  });
}
