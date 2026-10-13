// Executable host contracts; not ArkUI rendering or on-device acceptance.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { stripTypeScriptTypes } from 'node:module';
const root = new URL('../entry/src/main/ets/', import.meta.url);
const read = file => fs.readFileSync(new URL(file, root), 'utf8');
let state = { timer: { sessionUid: 'old', taskUid: 'task', target: { kind: 'TASK', uid: 'task' } } };
let dialog;
const commands = [];
const storage = new Map();
const sandbox = {
  KmpFocusTimerRepository: { getInstance: () => ({ state: async () => state, execute: async command => {
    commands.push(command); return { error: null, lastOutcome: 'APPLIED' };
  } }) },
  Toast: { show: () => {} }, FocusPresentation: { outcome: () => 'Changed' },
  AppStorage: { get: key => storage.get(key), setOrCreate: (key, value) => storage.set(key, value) }
};
vm.createContext(sandbox);
const code = stripTypeScriptTypes(read('pages/routes/focus/FocusChangeConfirmation.ets')
  .replace(/^import .*;\n/gm, '').replace(/\bexport /g, ''), { mode: 'transform' });
const coordinator = vm.runInContext(code + '\nFocusChangeConfirmation;', sandbox);
const flush = async () => { await Promise.resolve(); await Promise.resolve(); };
const context = { showAlertDialog: options => { dialog = options; } };
const cancelled = coordinator.request('task', false, false, 'MARK_COMPLETE');
await flush(); coordinator.present(context);
assert.equal(commands.length, 0);
dialog.primaryButton.action();
assert.equal(await cancelled, false);
assert.equal(commands.length, 0);
const confirmed = coordinator.request('task', false, true);
await flush(); coordinator.present(context);
state = { timer: { sessionUid: 'new', taskUid: 'task', target: { kind: 'TASK', uid: 'task' } } };
dialog.secondaryButton.action();
assert.equal(await confirmed, true);
assert.equal(commands.length, 1);
assert.equal(commands[0].sessionUid, 'old');
assert.equal(commands[0].operation, 'resolve_task_delete');
assert.equal(await coordinator.request('other', false, false, 'MARK_COMPLETE'), false);
state = { timer: { sessionUid: 'habit-session', taskUid: '', target: { kind: 'HABIT', uid: 'habit' } } };
const first = coordinator.request('habit', true, false);
const duplicate = coordinator.request('habit', true, true);
await flush(); coordinator.present(context);
assert.equal(await duplicate, false);
dialog.secondaryButton.action();
assert.equal(await first, true);
assert.equal(commands[1].habitUid, 'habit');
assert.equal(commands[1].sessionUid, 'habit-session');
assert.equal(commands[1].operation, 'resolve_habit_archive');
const warningCode = stripTypeScriptTypes(read('pages/routes/focus/FocusPresentation.ets').replace(/\bexport /g, ''), { mode: 'transform' });
const presentation = vm.runInContext(warningCode + '\nFocusPresentation;', sandbox);
const warnings = ['CLOCK_ANOMALY', 'LONG_RUNNING', 'EXCESSIVE_DURATION', 'ALARM_UNAVAILABLE'].map(presentation.warning);
assert.equal(new Set(warnings).size, 4);
assert(warnings.every(value => value.length > 0));
assert(warnings[1].includes('12 小时'));
const task = read('pages/components/TaskItemCard.ets');
const start = task.indexOf('// 1. 背景层');
const actions = task.slice(start, task.indexOf('} else {', start));
assert(actions.indexOf('this.primaryActionSymbol') < actions.indexOf('FocusSwipeAction'));
assert(actions.indexOf('FocusSwipeAction') < actions.indexOf('this.secondaryActionSymbol'));
const habit = read('pages/routes/main/HabitListSection.ets');
assert(habit.includes('this.habitSwipeActions(item.habit, true)'));
assert(habit.includes('this.habitSwipeActions(item.habit, false)'));
assert(habit.includes('this.isSelectionMode ? undefined'));
const sheet = read('pages/routes/focus/FocusTimerSheet.ets');
assert(sheet.includes("this.runCommand('complete_saved_task', 0, this.state.lastCompletedSession.uid)"));
assert(sheet.includes('this.state.lastCompletedTaskState === TaskState.COMPLETED'));
assert(sheet.includes('this.selectedSessionUid = next.lastCompletedSession.uid'));
assert(!sheet.includes("'计时状态需要注意：' + this.state.warning"));
console.log('Focus action host contracts passed: cancellation, confirmation, frozen session, duplicate request, habit archive, distinct warnings and swipe source contracts.');
