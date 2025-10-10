import os from 'os';
import path from 'path';

/**
 * Get the appropriate path module based on platform
 * @returns Platform-specific path module
 */
function getPathModule() {
  return process.platform === 'win32' ? path.win32 : path.posix;
}

/**
 * Expand tilde (~) to home directory
 * @param filePath - Path that may contain tilde
 * @returns Expanded path with home directory
 */
export function expandTilde(filePath: string): string {
  if (filePath === '~/') {
    return os.homedir() + '/';
  }
  if (filePath.startsWith('~/')) {
    const pathModule = getPathModule();
    return pathModule.join(os.homedir(), filePath.slice(2));
  }
  return filePath;
}

/**
 * Compress home directory to tilde (~) notation
 * @param filePath - Absolute path that may start with home directory
 * @returns Path with home directory replaced by tilde
 */
export function compressTilde(filePath: string): string {
  const homeDir = os.homedir();
  const pathModule = getPathModule();

  // Normalize paths for comparison
  const normalizedPath = pathModule.normalize(filePath);
  const normalizedHome = pathModule.normalize(homeDir);

  // Check if path starts with home directory
  if (normalizedPath === normalizedHome) {
    return '~';
  }

  // For cross-platform compatibility, check with trailing separator
  const homeWithSep = normalizedHome + pathModule.sep;
  if (normalizedPath.startsWith(homeWithSep)) {
    return '~' + pathModule.sep + normalizedPath.slice(homeWithSep.length);
  }

  return filePath;
}

/**
 * Get the default installation directory based on platform
 * @returns Default installation directory path
 */
export function getDefaultInstallDir(): string {
  const platform = process.platform;
  const pathModule = getPathModule();

  if (platform === 'win32') {
    const localAppData = process.env.LOCALAPPDATA;
    if (!localAppData) {
      throw new Error('LOCALAPPDATA environment variable not set');
    }
    return pathModule.join(localAppData, 'nvim', 'necromancer', 'plugins');
  }

  // Unix-like systems (Linux, macOS, etc.)
  return pathModule.join(os.homedir(), '.local', 'share', 'nvim', 'necromancer', 'plugins');
}

/**
 * Resolve the full path for a plugin installation
 * @param pluginName - Name of the plugin
 * @param customInstallDir - Optional custom installation directory
 * @returns Full absolute path to the plugin directory
 */
export function resolvePluginPath(pluginName: string, customInstallDir?: string): string {
  const installDir = customInstallDir ? expandTilde(customInstallDir) : getDefaultInstallDir();
  const pathModule = getPathModule();
  return pathModule.join(installDir, pluginName);
}
