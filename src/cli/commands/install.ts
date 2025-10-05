import { existsSync, rmSync } from 'fs';
import { parseConfigFile } from '../../core/config.js';
import { readLockFile, writeLockFile } from '../../core/lockfile.js';
import { installPlugin } from '../../core/installer.js';
import type { InstalledPlugin } from '../../models/plugin.js';
import { logInfo, logError, setVerbose } from '../../utils/logger.js';
import { ConfigError, ValidationError } from '../../utils/errors.js';

/**
 * Install command options
 */
export interface InstallOptions {
  config?: string;
  verbose?: boolean;
  autoClean?: boolean;
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

  // Try current directory
  if (existsSync('.necromancer.json')) {
    return '.necromancer.json';
  }

  // Try global config
  const globalConfig = `${process.env.HOME}/.config/necromancer/config.json`;
  if (existsSync(globalConfig)) {
    return globalConfig;
  }

  throw new ConfigError('Configuration file not found. Run "necromancer init" to create one.');
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
 * Install command implementation
 * @param options - Command options
 * @returns Exit code
 */
export function install(options: InstallOptions = {}): number {
  try {
    // Enable verbose logging if requested
    if (options.verbose) {
      setVerbose(true);
    }

    // Resolve config file path
    const configPath = resolveConfigPath(options.config);
    logInfo(`Using configuration file: ${configPath}`);

    // Parse config file
    const config = parseConfigFile(configPath);
    logInfo(`Found ${config.plugins.length} plugin(s) in configuration`);

    // Read lock file (or create empty if doesn't exist)
    const lockPath = getLockFilePath(configPath);
    const lockFile = readLockFile(lockPath);

    // Track installation results
    const results = {
      success: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: [] as string[]
    };

    // Install/update each plugin
    for (const plugin of config.plugins) {
      const status = installPlugin(plugin, config.installDir);

      switch (status.status) {
        case 'success':
          logInfo(`✓ ${plugin.name} [${plugin.commit.substring(0, 8)}] installed`);
          results.success++;
          break;
        case 'updated':
          logInfo(`✓ ${plugin.name} ${status.message}`);
          results.updated++;
          break;
        case 'skipped':
          logInfo(`✓ ${plugin.name} [${plugin.commit.substring(0, 8)}] already up-to-date`);
          results.skipped++;
          break;
        case 'failed':
          logError(`✗ ${plugin.name} failed: ${status.error?.message || status.message}`);
          results.failed++;
          results.errors.push(`${plugin.name}: ${status.error?.message || status.message}`);
          break;
      }

      // Update lock file with successful installations
      if (status.status === 'success' || status.status === 'updated' || status.status === 'skipped') {
        const installedPlugin: InstalledPlugin = {
          name: plugin.name,
          repo: plugin.repo,
          commit: plugin.commit,
          installedAt: new Date().toISOString(),
          path: config.installDir
            ? `${config.installDir}/${plugin.name}`
            : `${process.env.HOME}/.local/share/nvim/necromancer/plugins/${plugin.name}`
        };

        // Update or add to lock file
        const existingIndex = lockFile.plugins.findIndex(p => p.name === plugin.name);
        if (existingIndex >= 0) {
          lockFile.plugins[existingIndex] = installedPlugin;
        } else {
          lockFile.plugins.push(installedPlugin);
        }
      }
    }

    // Handle auto-clean if requested
    if (options.autoClean) {
      const configPluginNames = new Set(config.plugins.map(p => p.name));
      const orphanedPlugins = lockFile.plugins.filter(p => !configPluginNames.has(p.name));

      if (orphanedPlugins.length > 0) {
        logInfo(`\nRemoving ${orphanedPlugins.length} orphaned plugin(s)...`);
        for (const orphan of orphanedPlugins) {
          try {
            if (existsSync(orphan.path)) {
              rmSync(orphan.path, { recursive: true, force: true });
              logInfo(`✓ Removed ${orphan.name}`);
            }
          } catch (error) {
            logError(`✗ Failed to remove ${orphan.name}: ${(error as Error).message}`);
          }
        }

        // Remove orphaned plugins from lock file
        lockFile.plugins = lockFile.plugins.filter(p => configPluginNames.has(p.name));
      }
    }

    // Write updated lock file
    lockFile.generated = new Date().toISOString();
    writeLockFile(lockPath, lockFile);

    // Print summary
    logInfo('');
    if (results.failed === 0) {
      const total = results.success + results.updated + results.skipped;
      logInfo(`Successfully processed ${total} plugin(s)`);
      if (results.success > 0) logInfo(`  - ${results.success} installed`);
      if (results.updated > 0) logInfo(`  - ${results.updated} updated`);
      if (results.skipped > 0) logInfo(`  - ${results.skipped} already up-to-date`);
      return 0;
    } else {
      const successful = results.success + results.updated + results.skipped;
      logError(`${successful} plugin(s) succeeded, ${results.failed} failed`);
      return 2; // Partial failure
    }
  } catch (error) {
    if (error instanceof ConfigError || error instanceof ValidationError) {
      logError(`Error: ${error.message}`);
      return 1;
    }
    logError(`Error: ${(error as Error).message}`);
    return 3;
  }
}
