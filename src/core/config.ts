import { readFileSync } from 'fs';
import type { ConfigFile } from '../models/config-file.js';
import { ConfigError, ValidationError } from '../utils/errors.js';
import { isValidGitHubUrl, isValidCommitHash, isValidPluginName } from './validator.js';

/**
 * Parse and validate configuration file
 * @param path - Path to configuration file
 * @returns Parsed and validated ConfigFile
 * @throws ConfigError if file cannot be read or parsed
 * @throws ValidationError if configuration is invalid
 */
export function parseConfigFile(path: string): ConfigFile {
  let content: string;

  try {
    content = readFileSync(path, 'utf-8');
  } catch (error) {
    throw new ConfigError(`Failed to read configuration file at ${path}: ${(error as Error).message}`);
  }

  let config: ConfigFile;

  try {
    config = JSON.parse(content) as ConfigFile;
  } catch (error) {
    throw new ConfigError(`Invalid JSON in configuration file: ${(error as Error).message}`);
  }

  validateConfig(config);

  return config;
}

/**
 * Validate configuration file structure and content
 * @param config - Configuration to validate
 * @throws ValidationError if configuration is invalid
 */
export function validateConfig(config: ConfigFile): void {
  // Check that plugins array exists
  if (!config.plugins) {
    throw new ValidationError('Configuration must contain a "plugins" array');
  }

  // Check that plugins array is not empty
  if (!Array.isArray(config.plugins) || config.plugins.length === 0) {
    throw new ValidationError('Plugins array must not be empty');
  }

  const pluginNames = new Set<string>();

  // Validate each plugin
  for (let i = 0; i < config.plugins.length; i++) {
    const plugin = config.plugins[i];

    if (!plugin) {
      throw new ValidationError(`Plugin at index ${i} is undefined`);
    }

    // Check required fields
    if (!plugin.name) {
      throw new ValidationError(`Plugin at index ${i} is missing required field: name`);
    }
    if (!plugin.repo) {
      throw new ValidationError(`Plugin at index ${i} is missing required field: repo`);
    }
    if (!plugin.commit) {
      throw new ValidationError(`Plugin at index ${i} is missing required field: commit`);
    }

    // Validate plugin name
    if (!isValidPluginName(plugin.name)) {
      throw new ValidationError(`Invalid plugin name: "${plugin.name}"`);
    }

    // Check for duplicate names
    if (pluginNames.has(plugin.name)) {
      throw new ValidationError(`Duplicate plugin name: "${plugin.name}"`);
    }
    pluginNames.add(plugin.name);

    // Validate GitHub URL
    if (!isValidGitHubUrl(plugin.repo)) {
      throw new ValidationError(`Invalid GitHub URL for plugin "${plugin.name}": ${plugin.repo}`);
    }

    // Validate commit hash
    if (!isValidCommitHash(plugin.commit)) {
      throw new ValidationError(`Invalid commit hash for plugin "${plugin.name}": ${plugin.commit}`);
    }
  }
}
