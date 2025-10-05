import { readFileSync, writeFileSync } from 'fs';
import type { LockFile } from '../models/lockfile.js';
import { LOCK_FILE_VERSION, createEmptyLockFile } from '../models/lockfile.js';
import { ConfigError } from '../utils/errors.js';

/**
 * Read and parse lock file
 * @param path - Path to lock file
 * @returns Parsed LockFile, or empty lock file if file doesn't exist
 * @throws ConfigError if file exists but is invalid
 */
export function readLockFile(path: string): LockFile {
  let content: string;

  try {
    content = readFileSync(path, 'utf-8');
  } catch (error) {
    // If file doesn't exist, return empty lock file
    const err = error as NodeJS.ErrnoException;
    if (err.code === 'ENOENT') {
      return createEmptyLockFile();
    }
    throw new ConfigError(`Failed to read lock file at ${path}: ${err.message}`);
  }

  let lockFile: LockFile;

  try {
    lockFile = JSON.parse(content) as LockFile;
  } catch (error) {
    throw new ConfigError(`Invalid JSON in lock file: ${(error as Error).message}`);
  }

  // Validate lock file version
  if (lockFile.version !== LOCK_FILE_VERSION) {
    throw new ConfigError(`Unsupported lock file version: ${lockFile.version}. Expected: ${LOCK_FILE_VERSION}`);
  }

  return lockFile;
}

/**
 * Write lock file to disk
 * @param path - Path to lock file
 * @param lockFile - Lock file data to write
 * @throws ConfigError if write fails
 */
export function writeLockFile(path: string, lockFile: LockFile): void {
  try {
    const content = JSON.stringify(lockFile, null, 2);
    writeFileSync(path, content, 'utf-8');
  } catch (error) {
    throw new ConfigError(`Failed to write lock file at ${path}: ${(error as Error).message}`);
  }
}
