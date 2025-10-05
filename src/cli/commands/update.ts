import { install, type InstallOptions } from './install.js';

/**
 * Update command options
 */
export interface UpdateOptions extends InstallOptions {
  plugins?: string[];
}

/**
 * Update command implementation
 * This is essentially an alias for install, but can filter to specific plugins
 * @param options - Command options
 * @returns Exit code
 */
export async function update(options: UpdateOptions = {}): Promise<number> {
  // If specific plugins are requested, we would filter here
  // For now, update is the same as install (both handle updates intelligently)
  // The filtering by plugin name can be added as an enhancement

  if (options.plugins && options.plugins.length > 0) {
    // TODO: Filter config to only include specified plugins
    // For now, update all plugins
    console.warn('Warning: Plugin filtering not yet implemented. Updating all plugins.');
  }

  return install(options);
}
