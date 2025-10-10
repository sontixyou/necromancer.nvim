import { existsSync, rmSync, readSync } from 'fs';
import { parseConfigFile } from '../../core/config.js';
import { readLockFile, writeLockFile } from '../../core/lockfile.js';
import { logInfo, logError } from '../../utils/logger.js';
import { ConfigError } from '../../utils/errors.js';
import { expandTilde } from '../../utils/paths.js';

/**
 * Clean command options
 */
export interface CleanOptions {
  config?: string;
  dryRun?: boolean;
  force?: boolean;
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
 * Prompt user for confirmation (synchronous)
 * @param message - Prompt message
 * @returns True if confirmed
 */
function prompt(message: string): boolean {
  process.stdout.write(message + ' [y/N]: ');

  const buffer = Buffer.alloc(1024);
  const bytesRead = readSync(0, buffer, 0, 1024, null);
  const answer = buffer.toString('utf-8', 0, bytesRead).trim();

  return answer.toLowerCase() === 'y' || answer.toLowerCase() === 'yes';
}

/**
 * Clean command implementation
 * @param options - Command options
 * @returns Exit code
 */
export function clean(options: CleanOptions = {}): number {
  try {
    const configPath = resolveConfigPath(options.config);
    const config = parseConfigFile(configPath);

    const lockPath = getLockFilePath(configPath);
    const lockFile = readLockFile(lockPath);

    // Find orphaned plugins (in lock but not in config)
    const configPluginNames = new Set(config.plugins.map(p => p.name));
    const orphanedPlugins = lockFile.plugins.filter(p => !configPluginNames.has(p.name));

    if (orphanedPlugins.length === 0) {
      logInfo('No orphaned plugins found.');
      return 0;
    }

    // Dry run mode
    if (options.dryRun) {
      logInfo('The following plugins would be removed:');
      for (const orphan of orphanedPlugins) {
        logInfo(`  - ${orphan.name} (${orphan.path})`);
      }
      logInfo('');
      logInfo('Run "necromancer clean" to remove them.');
      return 0;
    }

    // Show what will be removed
    logInfo('The following plugins are no longer in your configuration:');
    for (const orphan of orphanedPlugins) {
      logInfo(`  - ${orphan.name}`);
    }
    logInfo('');

    // Confirm unless --force
    if (!options.force) {
      const confirmed = prompt('Remove these plugins?');
      if (!confirmed) {
        logInfo('Cancelled.');
        return 0;
      }
    }

    // Remove orphaned plugins
    let removed = 0;
    let failed = 0;

    for (const orphan of orphanedPlugins) {
      try {
        const absolutePath = expandTilde(orphan.path);
        if (existsSync(absolutePath)) {
          rmSync(absolutePath, { recursive: true, force: true });
          logInfo(`✓ Removed ${orphan.name}`);
          removed++;
        } else {
          logInfo(`✓ ${orphan.name} (directory already removed)`);
          removed++;
        }
      } catch (error) {
        logError(`✗ Failed to remove ${orphan.name}: ${(error as Error).message}`);
        failed++;
      }
    }

    // Update lock file to remove orphaned entries
    lockFile.plugins = lockFile.plugins.filter(p => configPluginNames.has(p.name));
    lockFile.generated = new Date().toISOString();
    writeLockFile(lockPath, lockFile);

    // Print summary
    logInfo('');
    if (failed === 0) {
      logInfo(`Removed ${removed} orphaned plugin(s)`);
      return 0;
    } else {
      logError(`Removed ${removed} plugin(s), ${failed} failed`);
      return 2;
    }
  } catch (error) {
    if (error instanceof ConfigError) {
      logError(`Error: ${error.message}`);
      return 1;
    }
    logError(`Error: ${(error as Error).message}`);
    return 2;
  }
}
