/**
 * Represents a plugin definition in the user's configuration file
 */
export interface PluginDefinition {
  /** Unique plugin identifier (used for directory name) */
  name: string;
  /** GitHub repository URL (https://github.com/owner/repo) */
  repo: string;
  /** 40-character SHA-1 commit hash */
  commit: string;
}

/**
 * Represents a plugin that has been successfully installed
 */
export interface InstalledPlugin extends PluginDefinition {
  /** ISO 8601 timestamp of installation */
  installedAt: string;
  /** Absolute path to installed plugin directory */
  path: string;
}

/**
 * Represents the status of a plugin installation operation
 */
export interface InstallationStatus {
  /** Plugin being installed */
  plugin: PluginDefinition;
  /** Operation result */
  status: 'success' | 'failed' | 'skipped' | 'updated';
  /** Human-readable status message */
  message: string;
  /** Error object if status is 'failed' */
  error?: Error;
}

/**
 * Represents the result of a git operation
 */
export interface GitOperationResult {
  /** Whether operation succeeded */
  success: boolean;
  /** stdout from git command */
  output: string;
  /** stderr if operation failed */
  error?: string;
  /** The git command that was executed (for logging) */
  command: string;
}
