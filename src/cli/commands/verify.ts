import { existsSync } from 'fs';
import { parseConfigFile } from '../../core/config.js';
import { readLockFile } from '../../core/lockfile.js';
import { verifyInstallation, repairPlugin } from '../../core/installer.js';
import { logInfo, logError } from '../../utils/logger.js';
import { ConfigError } from '../../utils/errors.js';

/**
 * Verify command options
 */
export interface VerifyOptions {
  config?: string;
  fix?: boolean;
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
 * Verify command implementation
 * @param options - Command options
 * @returns Exit code (0 = all verified, 2 = issues found)
 */
export function verify(options: VerifyOptions = {}): number {
  try {
    const configPath = resolveConfigPath(options.config);
    const config = parseConfigFile(configPath);

    const lockPath = getLockFilePath(configPath);
    const lockFile = readLockFile(lockPath);

    if (lockFile.plugins.length === 0) {
      logError('Warning: No lock file found. Run "necromancer install" first.');
      return 2;
    }

    // Track verification results
    let verified = 0;
    let issues = 0;
    let repaired = 0;

    // Verify each installed plugin
    for (const installed of lockFile.plugins) {
      const isValid = verifyInstallation(installed);

      if (isValid) {
        logInfo(`✓ ${installed.name} verified`);
        verified++;
      } else {
        if (options.fix) {
          // Try to repair
          logError(`✗ ${installed.name}: installation corrupted`);
          logInfo(`  → Repairing ${installed.name}...`);

          try {
            // Find the plugin definition in config
            const pluginDef = config.plugins.find(p => p.name === installed.name);
            if (pluginDef) {
              repairPlugin(pluginDef, installed.path);
              logInfo(`  ✓ ${installed.name} repaired`);
              repaired++;
            } else {
              logError(`  ✗ ${installed.name} not found in config, cannot repair`);
              issues++;
            }
          } catch (error) {
            logError(`  ✗ Failed to repair ${installed.name}: ${(error as Error).message}`);
            issues++;
          }
        } else {
          if (!existsSync(installed.path)) {
            logError(`✗ ${installed.name}: directory not found`);
          } else {
            logError(`✗ ${installed.name}: git repository corrupt (not a git repo)`);
          }
          issues++;
        }
      }
    }

    // Print summary
    logInfo('');
    if (options.fix && repaired > 0) {
      logInfo(`${verified + repaired} plugin(s) verified, ${repaired} repaired`);
    } else if (issues === 0) {
      logInfo(`All ${verified} plugin(s) verified successfully`);
    } else {
      logError(`${verified} verified, ${issues} with issues`);
    }

    return issues > 0 ? 2 : 0;
  } catch (error) {
    if (error instanceof ConfigError) {
      logError(`Error: ${error.message}`);
      return 1;
    }
    logError(`Error: ${(error as Error).message}`);
    return 3;
  }
}
