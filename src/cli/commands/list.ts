import { existsSync } from 'fs';
import { parseConfigFile } from '../../core/config.js';
import { readLockFile } from '../../core/lockfile.js';
import { getCurrentCommit } from '../../core/git.js';
import { logInfo, logError, setVerbose } from '../../utils/logger.js';
import { ConfigError } from '../../utils/errors.js';

/**
 * List command options
 */
export interface ListOptions {
  config?: string;
  verbose?: boolean;
}

/**
 * Resolve config file path
 * @param configPath - Optional config path from CLI args
 * @returns Resolved config file path
 */
function resolveConfigPath(configPath?: string): string {
  if (configPath) {
    return configPath;
  }

  if (existsSync('.necromancer.json')) {
    return '.necromancer.json';
  }

  const globalConfig = `${process.env.HOME}/.config/necromancer/config.json`;
  if (existsSync(globalConfig)) {
    return globalConfig;
  }

  throw new ConfigError('Configuration file not found');
}

/**
 * Get lock file path from config file path
 * @param configPath - Config file path
 * @returns Lock file path
 */
function getLockFilePath(configPath: string): string {
  if (configPath.endsWith('.necromancer.json')) {
    return configPath.replace('.necromancer.json', '.necromancer.lock');
  }
  if (configPath.endsWith('config.json')) {
    return configPath.replace('config.json', 'lock.json');
  }
  return configPath + '.lock';
}

/**
 * List command implementation
 * @param options - Command options
 * @returns Exit code
 */
export async function list(options: ListOptions = {}): Promise<number> {
  try {
    if (options.verbose) {
      setVerbose(true);
    }

    const configPath = resolveConfigPath(options.config);
    const config = parseConfigFile(configPath);

    const lockPath = getLockFilePath(configPath);
    const lockFile = readLockFile(lockPath);

    // Create a map of installed plugins for quick lookup
    const installedMap = new Map(lockFile.plugins.map(p => [p.name, p]));

    // Track status counts
    let upToDate = 0;
    let outdated = 0;
    let notInstalled = 0;

    // Check each configured plugin
    for (const plugin of config.plugins) {
      const installed = installedMap.get(plugin.name);

      if (!installed) {
        logInfo(`✗ ${plugin.name.padEnd(30)} [${plugin.commit.substring(0, 8)}] not installed`);
        notInstalled++;
        continue;
      }

      // Check if directory exists
      if (!existsSync(installed.path)) {
        logInfo(`✗ ${plugin.name.padEnd(30)} [${plugin.commit.substring(0, 8)}] directory not found`);
        notInstalled++;
        continue;
      }

      // Try to get current commit
      try {
        const currentCommit = getCurrentCommit(installed.path);

        if (currentCommit === plugin.commit) {
          if (options.verbose) {
            logInfo(`✓ ${plugin.name.padEnd(30)} [${plugin.commit.substring(0, 8)}] up-to-date`);
            logInfo(`    Repo: ${plugin.repo}`);
            logInfo(`    Path: ${installed.path}`);
            logInfo(`    Installed: ${installed.installedAt}`);
          } else {
            logInfo(`✓ ${plugin.name.padEnd(30)} [${plugin.commit.substring(0, 8)}] up-to-date`);
          }
          upToDate++;
        } else {
          logInfo(`⚠ ${plugin.name.padEnd(30)} [${plugin.commit.substring(0, 8)}] outdated (installed: [${currentCommit.substring(0, 8)}])`);
          outdated++;
        }
      } catch (error) {
        logInfo(`✗ ${plugin.name.padEnd(30)} [${plugin.commit.substring(0, 8)}] corrupted (not a valid git repo)`);
        notInstalled++;
      }
    }

    // Print summary
    logInfo('');
    const total = config.plugins.length;
    logInfo(`${total} plugin(s) total: ${upToDate} up-to-date, ${outdated} outdated, ${notInstalled} not installed`);

    return 0;
  } catch (error) {
    if (error instanceof ConfigError) {
      logError(`Error: ${error.message}`);
      return 1;
    }
    logError(`Error: ${(error as Error).message}`);
    return 1;
  }
}
