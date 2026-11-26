import { hapTasks, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { HvigorPlugin } from '@ohos/hvigor';
import { execFileSync } from 'child_process';
import { dirname, resolve } from 'path';

const root = resolve(__dirname, '..');

function syncCore(configuration: string): void {
  switch (process.env.DEADLINER_CORE_SOURCE || 'package') {
    case 'package':
      execFileSync(process.platform === 'win32' ? 'python' : 'python3', [
        resolve(root, 'scripts/core_package.py'), 'harmony',
        resolve(root, 'entry/libs/arm64-v8a/libDeadlinerCore.so'),
        '--lock', resolve(root, 'core-package.lock.json'),
      ], { stdio: 'inherit' });
      break;
    case 'local':
      const core = process.env.DEADLINER_CORE_DIR || resolve(root, '../DeadlinerCore');
      execFileSync(resolve(core, 'runscript/buildAndDeploy.sh'), [
        '--skip-android', '--skip-ios', '--configuration', configuration, '--harmony-repo', root,
      ], { stdio: 'inherit', env: {
        ...process.env,
        JAVA_HOME: process.env.DEADLINER_GRADLE_JAVA_HOME || process.env.JAVA_HOME ||
          execFileSync('/usr/libexec/java_home', ['-v', '21'], { encoding: 'utf8' }).trim(),
        DEVECO_HOME: process.env.DEVECO_HOME || resolve(dirname(process.execPath), '../../..'),
      } });
      break;
    default:
      throw new Error('DEADLINER_CORE_SOURCE must be package or local');
  }
}

const corePackage: HvigorPlugin = {
  pluginId: 'deadliner-core-package',
  apply(node) {
    node.afterNodeEvaluate(() => {
      const context = node.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext;
      const targets: string[] = [];
      context.targets(target => {
        const preBuild = target.getTargetName() + '@PreBuild';
        if (node.getTaskByName(preBuild)) targets.push(preBuild);
      });
      node.registerTask({
        name: 'syncDeadlinerCoreKmp',
        postDependencies: targets,
        run: () => syncCore(context.getBuildMode()),
      });
    });
  },
};

export default { system: hapTasks, plugins: [corePackage] };
