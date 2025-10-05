import { describe, it, expect } from 'vitest';
import {
  NecromancerError,
  ValidationError,
  GitError,
  ConfigError
} from '../../src/utils/errors.js';

describe('Error Classes', () => {
  describe('NecromancerError (base)', () => {
    it('should create error with message', () => {
      const error = new NecromancerError('Test error message');

      expect(error.message).toBe('Test error message');
      expect(error.name).toBe('NecromancerError');
    });

    it('should be instance of Error', () => {
      const error = new NecromancerError('Test');

      expect(error).toBeInstanceOf(Error);
      expect(error).toBeInstanceOf(NecromancerError);
    });

    it('should have stack trace', () => {
      const error = new NecromancerError('Test');

      expect(error.stack).toBeDefined();
      expect(error.stack).toContain('NecromancerError');
    });

    it('should preserve error message', () => {
      const message = 'This is a detailed error message';
      const error = new NecromancerError(message);

      expect(error.message).toBe(message);
    });
  });

  describe('ValidationError', () => {
    it('should extend NecromancerError', () => {
      const error = new ValidationError('Invalid input');

      expect(error).toBeInstanceOf(NecromancerError);
      expect(error).toBeInstanceOf(ValidationError);
      expect(error).toBeInstanceOf(Error);
    });

    it('should have correct name', () => {
      const error = new ValidationError('Invalid URL');

      expect(error.name).toBe('ValidationError');
    });

    it('should preserve validation message', () => {
      const message = 'Invalid plugin name: contains spaces';
      const error = new ValidationError(message);

      expect(error.message).toBe(message);
    });

    it('should be catchable as NecromancerError', () => {
      try {
        throw new ValidationError('Test');
      } catch (err) {
        expect(err).toBeInstanceOf(NecromancerError);
        expect(err).toBeInstanceOf(ValidationError);
      }
    });
  });

  describe('GitError', () => {
    it('should extend NecromancerError', () => {
      const error = new GitError('Git command failed');

      expect(error).toBeInstanceOf(NecromancerError);
      expect(error).toBeInstanceOf(GitError);
      expect(error).toBeInstanceOf(Error);
    });

    it('should have correct name', () => {
      const error = new GitError('Clone failed');

      expect(error.name).toBe('GitError');
    });

    it('should preserve git error message', () => {
      const message = 'Failed to clone repository: network error';
      const error = new GitError(message);

      expect(error.message).toBe(message);
    });

    it('should be distinguishable from ValidationError', () => {
      const gitError = new GitError('Git failed');
      const validationError = new ValidationError('Invalid');

      expect(gitError).not.toBeInstanceOf(ValidationError);
      expect(validationError).not.toBeInstanceOf(GitError);
    });
  });

  describe('ConfigError', () => {
    it('should extend NecromancerError', () => {
      const error = new ConfigError('Config file not found');

      expect(error).toBeInstanceOf(NecromancerError);
      expect(error).toBeInstanceOf(ConfigError);
      expect(error).toBeInstanceOf(Error);
    });

    it('should have correct name', () => {
      const error = new ConfigError('Invalid JSON');

      expect(error.name).toBe('ConfigError');
    });

    it('should preserve config error message', () => {
      const message = 'Configuration file is invalid: duplicate plugin names';
      const error = new ConfigError(message);

      expect(error.message).toBe(message);
    });
  });

  describe('Error Type Checking', () => {
    it('should allow type guards for specific errors', () => {
      const checkErrorType = (err: unknown): string => {
        if (err instanceof ValidationError) {
          return 'validation';
        } else if (err instanceof GitError) {
          return 'git';
        } else if (err instanceof ConfigError) {
          return 'config';
        } else if (err instanceof NecromancerError) {
          return 'necromancer';
        }
        return 'unknown';
      };

      expect(checkErrorType(new ValidationError('test'))).toBe('validation');
      expect(checkErrorType(new GitError('test'))).toBe('git');
      expect(checkErrorType(new ConfigError('test'))).toBe('config');
      expect(checkErrorType(new NecromancerError('test'))).toBe('necromancer');
    });

    it('should maintain instanceof relationships', () => {
      const errors = [
        new ValidationError('test'),
        new GitError('test'),
        new ConfigError('test')
      ];

      errors.forEach(err => {
        expect(err).toBeInstanceOf(NecromancerError);
        expect(err).toBeInstanceOf(Error);
      });
    });
  });

  describe('Error Stack Traces', () => {
    it('should include function names in stack trace', () => {
      function throwValidationError() {
        throw new ValidationError('Test error');
      }

      try {
        throwValidationError();
      } catch (err) {
        expect(err).toBeInstanceOf(ValidationError);
        if (err instanceof Error) {
          expect(err.stack).toContain('throwValidationError');
        }
      }
    });

    it('should preserve stack trace location', () => {
      const error = new GitError('Test');

      expect(error.stack).toContain('errors.test.ts');
    });
  });
});
