import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { logInfo, logError, logVerbose, setVerbose } from '../../src/utils/logger.js';

describe('Logger Utility', () => {
  let stdoutSpy: ReturnType<typeof vi.spyOn>;
  let stderrSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    // Spy on stdout and stderr
    stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(() => true);
    stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(() => true);

    // Reset verbose mode
    setVerbose(false);
  });

  afterEach(() => {
    stdoutSpy.mockRestore();
    stderrSpy.mockRestore();
  });

  describe('logInfo', () => {
    it('should write to stdout', () => {
      logInfo('Test message');

      expect(stdoutSpy).toHaveBeenCalled();
      expect(stderrSpy).not.toHaveBeenCalled();
    });

    it('should include message content', () => {
      logInfo('Installation complete');

      const output = stdoutSpy.mock.calls[0]?.[0] as string;
      expect(output).toContain('Installation complete');
    });

    it('should append newline', () => {
      logInfo('Test');

      const output = stdoutSpy.mock.calls[0]?.[0] as string;
      expect(output).toMatch(/\n$/);
    });

    it('should handle multi-line messages', () => {
      logInfo('Line 1\nLine 2');

      expect(stdoutSpy).toHaveBeenCalled();
    });
  });

  describe('logError', () => {
    it('should write to stderr', () => {
      logError('Error message');

      expect(stderrSpy).toHaveBeenCalled();
      expect(stdoutSpy).not.toHaveBeenCalled();
    });

    it('should include error content', () => {
      logError('Failed to clone repository');

      const output = stderrSpy.mock.calls[0]?.[0] as string;
      expect(output).toContain('Failed to clone repository');
    });

    it('should append newline', () => {
      logError('Error');

      const output = stderrSpy.mock.calls[0]?.[0] as string;
      expect(output).toMatch(/\n$/);
    });

    it('should handle error objects', () => {
      const error = new Error('Test error');
      logError(error.message);

      const output = stderrSpy.mock.calls[0]?.[0] as string;
      expect(output).toContain('Test error');
    });
  });

  describe('logVerbose', () => {
    it('should not output when verbose mode is disabled', () => {
      setVerbose(false);
      logVerbose('Verbose message');

      expect(stdoutSpy).not.toHaveBeenCalled();
      expect(stderrSpy).not.toHaveBeenCalled();
    });

    it('should output to stdout when verbose mode is enabled', () => {
      setVerbose(true);
      logVerbose('Verbose message');

      expect(stdoutSpy).toHaveBeenCalled();
      expect(stderrSpy).not.toHaveBeenCalled();
    });

    it('should include verbose message content when enabled', () => {
      setVerbose(true);
      logVerbose('Executing git command: git clone...');

      const output = stdoutSpy.mock.calls[0]?.[0] as string;
      expect(output).toContain('git clone');
    });

    it('should handle verbose flag toggle', () => {
      // Initially disabled
      setVerbose(false);
      logVerbose('Should not appear');
      expect(stdoutSpy).not.toHaveBeenCalled();

      // Enable
      setVerbose(true);
      logVerbose('Should appear');
      expect(stdoutSpy).toHaveBeenCalledTimes(1);

      // Disable again
      setVerbose(false);
      logVerbose('Should not appear again');
      expect(stdoutSpy).toHaveBeenCalledTimes(1); // Still only 1 call
    });
  });

  describe('No File I/O', () => {
    it('should not create any log files', () => {
      const fsSpy = vi.spyOn(require('fs'), 'writeFileSync');

      logInfo('Test');
      logError('Error');
      setVerbose(true);
      logVerbose('Verbose');

      expect(fsSpy).not.toHaveBeenCalled();
      fsSpy.mockRestore();
    });

    it('should not append to any files', () => {
      const fsSpy = vi.spyOn(require('fs'), 'appendFileSync');

      logInfo('Test');
      logError('Error');

      expect(fsSpy).not.toHaveBeenCalled();
      fsSpy.mockRestore();
    });
  });

  describe('Message Formatting', () => {
    it('should preserve exact message without modification', () => {
      const message = 'Exact message with [special] {characters}';
      logInfo(message);

      const output = stdoutSpy.mock.calls[0]?.[0] as string;
      expect(output).toContain(message);
    });

    it('should handle empty messages', () => {
      logInfo('');

      expect(stdoutSpy).toHaveBeenCalled();
      const output = stdoutSpy.mock.calls[0]?.[0] as string;
      expect(output).toBe('\n');
    });

    it('should handle special characters', () => {
      logInfo('✓ Success');

      const output = stdoutSpy.mock.calls[0]?.[0] as string;
      expect(output).toContain('✓');
    });
  });

  describe('Synchronous Behavior', () => {
    it('should execute synchronously (no promises)', () => {
      const result = logInfo('Test');

      // If it returns a promise, this would be truthy
      expect(result).toBeUndefined();
    });

    it('should complete immediately', () => {
      const before = Date.now();
      logInfo('Test');
      const after = Date.now();

      // Should complete in less than 10ms (synchronous)
      expect(after - before).toBeLessThan(10);
    });
  });
});
