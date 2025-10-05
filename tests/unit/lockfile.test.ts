import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { writeFileSync, unlinkSync, mkdirSync, rmdirSync, existsSync } from 'fs';
import { join } from 'path';
import { readLockFile, writeLockFile } from '../../src/core/lockfile.js';
import type { LockFile } from '../../src/models/lockfile.js';

describe('Lock File Operations', () => {
  const testDir = join(process.cwd(), 'test-tmp-lock');
  const lockPath = join(testDir, '.necromancer.lock');

  beforeEach(() => {
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    try {
      if (existsSync(lockPath)) {
        unlinkSync(lockPath);
      }
    } catch {
      // File might not exist
    }
    try {
      rmdirSync(testDir);
    } catch {
      // Directory might not be empty
    }
  });

  describe('readLockFile', () => {
    it('should read valid lock file with plugins', () => {
      const lockData: LockFile = {
        version: '1',
        generated: '2025-10-05T12:34:56Z',
        plugins: [
          {
            name: 'plenary.nvim',
            repo: 'https://github.com/nvim-lua/plenary.nvim',
            commit: 'a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683',
            installedAt: '2025-10-05T12:34:56Z',
            path: '/home/user/.local/share/nvim/necromancer/plugins/plenary.nvim'
          }
        ]
      };

      writeFileSync(lockPath, JSON.stringify(lockData, null, 2));
      const result = readLockFile(lockPath);

      expect(result.version).toBe('1');
      expect(result.plugins).toHaveLength(1);
      expect(result.plugins[0]?.name).toBe('plenary.nvim');
    });

    it('should return empty lock file when file does not exist', () => {
      const nonExistentPath = join(testDir, 'does-not-exist.lock');
      const result = readLockFile(nonExistentPath);

      expect(result.version).toBe('1');
      expect(result.plugins).toHaveLength(0);
      expect(result.generated).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    });

    it('should throw error for invalid lock file version', () => {
      const invalidVersion = {
        version: '2',
        generated: '2025-10-05T12:34:56Z',
        plugins: []
      };

      writeFileSync(lockPath, JSON.stringify(invalidVersion, null, 2));
      expect(() => readLockFile(lockPath)).toThrow(/unsupported.*version/i);
    });

    it('should throw error for corrupted JSON', () => {
      writeFileSync(lockPath, '{corrupted json');
      expect(() => readLockFile(lockPath)).toThrow();
    });

    it('should read lock file with multiple plugins', () => {
      const multipleLockData: LockFile = {
        version: '1',
        generated: '2025-10-05T12:34:56Z',
        plugins: [
          {
            name: 'plenary.nvim',
            repo: 'https://github.com/nvim-lua/plenary.nvim',
            commit: 'a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683',
            installedAt: '2025-10-05T12:34:56Z',
            path: '/path/to/plenary'
          },
          {
            name: 'telescope.nvim',
            repo: 'https://github.com/nvim-telescope/telescope.nvim',
            commit: '0dfbf5e48e8551212c2a9f1c5614d008f4e86eba',
            installedAt: '2025-10-05T12:35:00Z',
            path: '/path/to/telescope'
          }
        ]
      };

      writeFileSync(lockPath, JSON.stringify(multipleLockData, null, 2));
      const result = readLockFile(lockPath);

      expect(result.plugins).toHaveLength(2);
    });
  });

  describe('writeLockFile', () => {
    it('should write lock file with version and timestamp', () => {
      const lockData: LockFile = {
        version: '1',
        generated: '2025-10-05T12:34:56Z',
        plugins: []
      };

      writeLockFile(lockPath, lockData);

      expect(existsSync(lockPath)).toBe(true);
      const content = JSON.parse(require('fs').readFileSync(lockPath, 'utf-8'));
      expect(content.version).toBe('1');
      expect(content.generated).toBe('2025-10-05T12:34:56Z');
    });

    it('should write lock file with plugin entries', () => {
      const lockData: LockFile = {
        version: '1',
        generated: '2025-10-05T12:34:56Z',
        plugins: [
          {
            name: 'plenary.nvim',
            repo: 'https://github.com/nvim-lua/plenary.nvim',
            commit: 'a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683',
            installedAt: '2025-10-05T12:34:56Z',
            path: '/path/to/plenary'
          }
        ]
      };

      writeLockFile(lockPath, lockData);

      const content = JSON.parse(require('fs').readFileSync(lockPath, 'utf-8'));
      expect(content.plugins).toHaveLength(1);
      expect(content.plugins[0].name).toBe('plenary.nvim');
    });

    it('should overwrite existing lock file', () => {
      const firstLock: LockFile = {
        version: '1',
        generated: '2025-10-05T12:00:00Z',
        plugins: []
      };

      const secondLock: LockFile = {
        version: '1',
        generated: '2025-10-05T13:00:00Z',
        plugins: [
          {
            name: 'new-plugin',
            repo: 'https://github.com/owner/new-plugin',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            installedAt: '2025-10-05T13:00:00Z',
            path: '/path/to/new-plugin'
          }
        ]
      };

      writeLockFile(lockPath, firstLock);
      writeLockFile(lockPath, secondLock);

      const content = JSON.parse(require('fs').readFileSync(lockPath, 'utf-8'));
      expect(content.generated).toBe('2025-10-05T13:00:00Z');
      expect(content.plugins).toHaveLength(1);
    });

    it('should create lock file with formatted JSON', () => {
      const lockData: LockFile = {
        version: '1',
        generated: '2025-10-05T12:34:56Z',
        plugins: []
      };

      writeLockFile(lockPath, lockData);

      const content = require('fs').readFileSync(lockPath, 'utf-8');
      // Check if JSON is formatted (has newlines and indentation)
      expect(content).toContain('\n');
      expect(content).toContain('  '); // Indentation
    });
  });
});
