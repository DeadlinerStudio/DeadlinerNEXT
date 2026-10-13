import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript');
const directory = new URL('../entry/src/main/ets/pages/routes/overview/', import.meta.url);
function moduleSource(name) {
  return fs.readFileSync(new URL(name, directory), 'utf8').replace(/^import[\s\S]*?;\n/gm, '').replace(/@Observed\n/g, '').replace(/export /g, '');
}
const memory = new Map();
let flushFailure = false;
const store = {
  getSync: (key, fallback) => memory.has(key) ? memory.get(key) : fallback,
  putSync: (key, value) => memory.set(key, value),
  deleteSync: key => memory.delete(key),
  flush: async () => { if (flushFailure) throw Error('disk failure'); }
};
let calls = 0, failAI = false, legacy = '', key = 'configured';
let archiveFailure = false, archivedTasks = [1, 2], archivedHabits = [1];
const sandbox = {
  preferences: { getPreferencesSync: () => store },
  LocalValues: { getInstance: () => ({ getMonthlyAnalysis: () => legacy, getDeepSeekApiKey: () => key }) },
  AIService: { getInstance: () => ({ generateMonthlyAnalysis: async () => {
    calls++; await Promise.resolve();
    if (failAI) throw Error('offline');
    return { summary: 'Real generated result', keywords: ['test'], generatedAt: 'date' };
  } }) },
  TaskRepository: { getInstance: () => ({ getArchivedDDLs: async () => { if (archiveFailure) throw Error('offline'); return archivedTasks; } }) },
  HabitRepository: { getInstance: () => ({ getArchivedHabits: async () => archivedHabits }) },
  MarkerView: class {},
  Date, Map, Promise
};
vm.createContext(sandbox);
const source = moduleSource('OverviewDashboardModel.ets') + '\n' + moduleSource('MonthlyInsightRepository.ets') + '\n' + moduleSource('OverviewTrendPresentation.ets') + '\n' + moduleSource('OverviewTrendMarker.ets') +
  '\nglobalThis.Rules = OverviewMonthRules; globalThis.Repository = MonthlyInsightRepository; globalThis.Dashboard = OverviewDashboardModel; globalThis.Trends = OverviewTrendPresentation; globalThis.Period = OverviewTrendPeriod; globalThis.TrendAxis = OverviewTrendAxisFormatter;';
vm.runInContext(ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2021 } }).outputText, sandbox);
const { Rules, Repository, Dashboard, Trends, Period, TrendAxis } = sandbox;
const groupedAxis = new TrendAxis(['31', '1', '2'], true);
assert.equal(groupedAxis.getFormattedValue(0.5, {}), '31');
assert.equal(groupedAxis.getFormattedValue(1.5, {}), '1');
assert.equal(groupedAxis.getFormattedValue(3.5, {}), '');
const chartTheme = { chartCompleted: 'green', chartOverdue: 'red', chartInfo: 'blue', chartTodo: 'orange' };
const dayStats = [{ fullDate: '2025-12-31', completed: 2, overdue: 1 }, { fullDate: '2026-01-01', completed: 3, overdue: 2 }];
assert.deepEqual(Array.from(Trends.dailyLabels(dayStats)), ['31', '1']);
assert.equal(Trends.dailySeries(dayStats, chartTheme, false).length, 1);
assert.equal(Trends.dailySeries(dayStats, chartTheme, true)[1].details[1], '2026-01-01\n逾期未完成 2 项');
const months = Array.from({ length: 12 }, (_, i) => ({ monthStr: (i + 1) + '月', total: 3, completed: 2, overdue: 1 }));
assert.equal(Trends.monthlySeries(months, chartTheme)[0].values.length, 12);
assert.equal(Trends.monthlySeries(months, chartTheme)[2].color, 'orange');
const point = { startDate: '2024-02-01', endDateExclusive: '2024-03-01', durationSeconds: 91,
  durationByTarget: { taskDurationSeconds: 60, habitDurationSeconds: 31 } };
assert.equal(Trends.focusSeries([point], chartTheme)[0].values[0], 91 / 60);
assert.match(Trends.focusDetail(point), /2024-02-01 – 2024-02-29/);
assert.match(Trends.focusDetail(point), /专注 1 分 31 秒/);
assert.match(Trends.focusDetail(point), /习惯 31 秒/);
assert.equal(Trends.focusLabels([point], Period.MONTHLY)[0], '2');
assert.equal(Trends.focusLabels([point], Period.WEEKLY)[0], '02-01');
assert.equal(Trends.preciseDuration(3661), '1 小时 1 分 1 秒');
const dashboard = new Dashboard();
assert.equal(dashboard.archiveValue(), '加载中');
await dashboard.loadArchive();
assert.equal(dashboard.state, null);
assert.equal(dashboard.archiveValue(), '3 项');
dashboard.month = '2025-01-01';
assert.equal(dashboard.archiveValue(), '3 项');
archiveFailure = true;
await dashboard.loadArchive();
assert.equal(dashboard.archiveValue(), '3 项');
const failedArchive = new Dashboard();
await failedArchive.loadArchive();
assert.equal(failedArchive.archiveValue(), '加载失败');
assert.equal(failedArchive.archiveLoading, false);
archiveFailure = false; archivedTasks = []; archivedHabits = [];
await failedArchive.loadArchive();
assert.equal(failedArchive.archiveValue(), '0 项');
assert.equal(failedArchive.archiveError, '');
const projection = (monthStart, asOfDate, daily) => ({ monthStart, asOfDate, daily: daily.map(([date, completedCount]) => ({ date, completedCount })) });
assert.equal(Rules.shift('2026-01-01', -1), '2025-12-01');
assert.equal(Rules.shift('2024-02-01', 1), '2024-03-01');
let pair = Rules.comparison(projection('2026-10-01', '2026-10-13', [['2026-10-13', 2], ['2026-10-14', 90]]),
  projection('2026-09-01', '2026-10-13', [['2026-09-13', 3], ['2026-09-14', 90]]));
assert.deepEqual(Array.from(pair), [2, 3]);
pair = Rules.comparison(projection('2024-03-01', '2026-10-13', [['2024-03-31', 4]]),
  projection('2024-02-01', '2026-10-13', [['2024-02-29', 5]]));
assert.deepEqual(Array.from(pair), [4, 5]);
const ended = Rules.shift(Rules.monthStart(), -1).slice(0, 7);
const repo = new Repository(); repo.init({});
const requests = await Promise.all([repo.load(ended, '上月', [], []), repo.load(ended, '上月', [], [])]);
assert.equal(calls, 1); assert.equal(requests[0].summary, requests[1].summary);
await repo.load(ended, '上月', [], [], true); assert.equal(calls, 1);
const restarted = new Repository(); restarted.init({});
await restarted.load(ended, '上月', [], []); assert.equal(calls, 1);
assert.equal(await repo.load(Rules.monthStart().slice(0, 7), '本月', [], [], true), null);
assert.equal(calls, 1);
const failedMonth = Rules.shift(ended + '-01', -1).slice(0, 7);
failAI = true;
assert.equal(await repo.load(failedMonth, '历史月', [], []), null); const failedCalls = calls;
await restarted.load(failedMonth, '历史月', [], []); assert.equal(calls, failedCalls);
failAI = false; await repo.load(failedMonth, '历史月', [], [], true); assert.equal(calls, failedCalls + 1);
const diskMonth = Rules.shift(failedMonth + '-01', -1).slice(0, 7);
flushFailure = true; assert.equal(await repo.load(diskMonth, '历史月', [], []), null); assert.equal(calls, failedCalls + 1);
flushFailure = false;
const legacyMonth = Rules.shift(diskMonth + '-01', -1).slice(0, 7);
legacy = JSON.stringify({ month: legacyMonth, summary: 'Legacy result', keywords: [] });
assert.equal((await repo.load(legacyMonth, '历史月', [], [])).summary, 'Legacy result');
assert.equal(calls, failedCalls + 1);
console.log('Overview contract checks passed: trend 12-month/overdue visibility/labels/leap-day exclusive ranges/fractional minutes/exact seconds/target breakdown, independent archive counts/month selection/failure recovery/empty archive, month/cross-year/leap-day/cutoff, AI coalescing/restart/immutable success/current-month gate/explicit retry/storage failure/legacy migration.');
