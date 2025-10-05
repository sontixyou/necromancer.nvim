import type { InstalledPlugin } from './plugin.js';

/**
 * Represents the lock file that tracks installation state
 */
export interface LockFile {
  /** Lock file format version (currently "1") */
  version: string;
  /** ISO 8601 timestamp of lock file generation */
  generated: string;
  /** Array of installed plugins */
  plugins: InstalledPlugin[];
}

/**
 * Current lock file version
 */
export const LOCK_FILE_VERSION = '1';

/**
 * Creates an empty lock file with current timestamp
 */
export function createEmptyLockFile(): LockFile {
  return {
    version: LOCK_FILE_VERSION,
    generated: new Date().toISOString(),
    plugins: []
  };
}
