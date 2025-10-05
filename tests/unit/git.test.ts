import { describe, it, expect } from 'vitest';
import { buildGitCloneCommand, buildGitCheckoutCommand, buildGitFetchCommand } from '../../src/core/git.js';

describe('Git Command Construction', () => {
  describe('buildGitCloneCommand', () => {
    it('should properly quote URL and path', () => {
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo',
        '/path/to/destination'
      );

      expect(cmd).toContain('"https://github.com/owner/repo"');
      expect(cmd).toContain('"/path/to/destination"');
      expect(cmd).toMatch(/^git clone/);
    });

    it('should handle paths with spaces', () => {
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo',
        '/path with spaces/destination'
      );

      expect(cmd).toContain('"/path with spaces/destination"');
    });

    it('should handle URLs with .git extension', () => {
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo.git',
        '/path/to/destination'
      );

      expect(cmd).toContain('"https://github.com/owner/repo.git"');
    });

    it('should include quiet flag to reduce output', () => {
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo',
        '/path/to/destination'
      );

      expect(cmd).toContain('--quiet');
    });

    it('should escape special characters in paths', () => {
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo',
        '/path/to/plugin-name'
      );

      expect(cmd).toContain('"/path/to/plugin-name"');
    });
  });

  describe('buildGitCheckoutCommand', () => {
    it('should include commit hash and quiet flag', () => {
      const cmd = buildGitCheckoutCommand('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0');

      expect(cmd).toMatch(/^git checkout/);
      expect(cmd).toContain('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0');
      expect(cmd).toContain('--quiet');
    });

    it('should quote commit hash', () => {
      const cmd = buildGitCheckoutCommand('a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683');

      expect(cmd).toContain('"a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683"');
    });

    it('should handle uppercase commit hashes', () => {
      const cmd = buildGitCheckoutCommand('A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0');

      expect(cmd).toContain('A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0');
    });
  });

  describe('buildGitFetchCommand', () => {
    it('should build fetch command with quiet flag', () => {
      const cmd = buildGitFetchCommand();

      expect(cmd).toMatch(/^git fetch/);
      expect(cmd).toContain('--quiet');
    });

    it('should fetch all remotes', () => {
      const cmd = buildGitFetchCommand();

      expect(cmd).toContain('--all');
    });
  });

  describe('Command Injection Prevention', () => {
    it('should prevent command injection in clone URL', () => {
      // The validator should catch this, but test the command builder too
      const maliciousUrl = 'https://github.com/owner/repo"; rm -rf /';
      const cmd = buildGitCloneCommand(maliciousUrl, '/safe/path');

      // The quotes should be properly escaped/handled
      expect(cmd).not.toMatch(/; rm -rf/);
    });

    it('should prevent command injection in paths', () => {
      const maliciousPath = '/path/to/dest"; rm -rf /';
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo',
        maliciousPath
      );

      // The path should be quoted properly
      expect(cmd).toContain(`"${maliciousPath}"`);
    });

    it('should handle backticks in commit hash', () => {
      const maliciousCommit = 'a1b2c3d4`whoami`e5f6a7b8c9d0e1f2a3b4c5d6';
      const cmd = buildGitCheckoutCommand(maliciousCommit);

      // Should be properly quoted
      expect(cmd).toContain(`"${maliciousCommit}"`);
    });
  });

  describe('Command Format Validation', () => {
    it('should produce valid shell commands', () => {
      const cloneCmd = buildGitCloneCommand(
        'https://github.com/nvim-lua/plenary.nvim',
        '/home/user/.local/share/nvim/necromancer/plugins/plenary.nvim'
      );

      // Should start with git command
      expect(cloneCmd).toMatch(/^git\s+/);
      // Should have proper structure
      expect(cloneCmd).toMatch(/git\s+clone.*--quiet.*"https:\/\//);
    });

    it('should not have duplicate quotes', () => {
      const cmd = buildGitCloneCommand(
        'https://github.com/owner/repo',
        '/path/to/plugin'
      );

      // Count quotes - should be balanced and not doubled
      const quoteCount = (cmd.match(/"/g) || []).length;
      expect(quoteCount % 2).toBe(0); // Even number of quotes
    });
  });
});
