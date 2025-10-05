/**
 * Base error class for all Necromancer errors
 */
export class NecromancerError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NecromancerError';

    // Maintains proper stack trace for where our error was thrown (only available on V8)
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

/**
 * Error thrown when input validation fails
 */
export class ValidationError extends NecromancerError {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * Error thrown when git operations fail
 */
export class GitError extends NecromancerError {
  constructor(message: string) {
    super(message);
    this.name = 'GitError';
  }
}

/**
 * Error thrown when configuration file operations fail
 */
export class ConfigError extends NecromancerError {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}
