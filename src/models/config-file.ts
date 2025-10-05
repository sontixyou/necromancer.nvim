import type { PluginDefinition } from './plugin.js';

/**
 * Represents the entire user configuration file
 */
export interface ConfigFile {
  /** Array of plugin definitions */
  plugins: PluginDefinition[];
  /** Optional custom installation directory (defaults to standard path) */
  installDir?: string;
}

/**
 * Default installation directory for Unix-like systems
 */
export const DEFAULT_UNIX_INSTALL_DIR = '~/.local/share/nvim/necromancer/plugins';

/**
 * Default installation directory for Windows
 * Note: This is a template, actual path uses %LOCALAPPDATA%
 */
export const DEFAULT_WINDOWS_INSTALL_DIR = '%LOCALAPPDATA%\\nvim\\necromancer\\plugins';
