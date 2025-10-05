/**
 * Logger utility for synchronous stdout/stderr logging
 * No file I/O - console only
 */

let verboseMode = false;

/**
 * Set verbose mode
 * @param enabled - Whether to enable verbose logging
 */
export function setVerbose(enabled: boolean): void {
  verboseMode = enabled;
}

/**
 * Log informational message to stdout
 * @param message - Message to log
 */
export function logInfo(message: string): void {
  process.stdout.write(message + '\n');
}

/**
 * Log error message to stderr
 * @param message - Error message to log
 */
export function logError(message: string): void {
  process.stderr.write(message + '\n');
}

/**
 * Log verbose message to stdout (only if verbose mode is enabled)
 * @param message - Verbose message to log
 */
export function logVerbose(message: string): void {
  if (verboseMode) {
    process.stdout.write(message + '\n');
  }
}
