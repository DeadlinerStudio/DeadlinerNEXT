import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { HvigorPlugin, HvigorTask } from '@ohos/hvigor';
import { execFileSync } from 'child_process';
import { existsSync } from 'fs';
import { resolve } from 'path';

const syncDeadlinerCoreKmpTask: HvigorTask = {
  name: 'syncDeadlinerCoreKmp',
  postDependencies: ['default@PreBuild'],
  run: () => {
    const coreDirectory: string = process.env.DEADLINER_CORE_DIR ||
      resolve(__dirname, '../../DeadlinerCore');
    const deployScript: string = resolve(coreDirectory, 'runscript/buildAndDeploy.sh');
    if (!existsSync(deployScript)) {
      throw new Error(
        'Deadliner Core was not found at ' + coreDirectory +
          '. Set DEADLINER_CORE_DIR to its checkout.',
      );
    }
    const gradleJavaHome: string = process.env.DEADLINER_GRADLE_JAVA_HOME ||
      execFileSync('/usr/libexec/java_home', ['-v', '21'], { encoding: 'utf8' }).trim();
    execFileSync(
      deployScript,
      ['--skip-ios', '--skip-android', '--harmony-repo', resolve(__dirname, '..')],
      { stdio: 'inherit', env: { ...process.env, JAVA_HOME: gradleJavaHome } },
    );
  },
};

const deadlinerCoreKmpAutoSyncPlugin: HvigorPlugin = {
  pluginId: 'deadliner-core-kmp-auto-sync',
  apply: (node) => {
    node.registerTask(syncDeadlinerCoreKmpTask);
  },
};

export default {
  system: hapTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [deadlinerCoreKmpAutoSyncPlugin] /* Build and deploy KMP before PreBuild. */
}
