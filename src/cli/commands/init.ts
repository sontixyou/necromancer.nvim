import { existsSync, writeFileSync } from 'fs';
import { logInfo, logError } from '../../utils/logger.js';
import type { ConfigFile } from '../../models/config-file.js';

/**
 * Init command options
 */
export interface InitOptions {
  config?: string;
  force?: boolean;
}

/**
 * Init command implementation
 * @param options - Command options
 * @returns Exit code
 */
export function init(options: InitOptions = {}): number {
  try {
    const configPath = options.config || '.necromancer.json';

    // Check if config already exists
    if (existsSync(configPath) && !options.force) {
      logError(`Error: Configuration file already exists at ${configPath}`);
      logInfo('Use --force to overwrite.');
      return 1;
    }

    // Create example configuration
    const exampleConfig: ConfigFile = {
      plugins: [
        {
          name: 'example-plugin',
          repo: 'https://github.com/owner/repository',
          commit: '0000000000000000000000000000000000000000'
        }
      ]
    };

    // Write configuration file
    const content = JSON.stringify(exampleConfig, null, 2);
    writeFileSync(configPath, content, 'utf-8');

    logInfo(`Created configuration file at ${configPath}`);
    logInfo('');
    logInfo('Edit the file to add your Neovim plugins, then run:');
    logInfo('  necromancer install');

    return 0;
  } catch (error) {
    logError(`Error: Failed to create configuration file: ${(error as Error).message}`);
    return 2;
  }
}
