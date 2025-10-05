import { describe, it, expect } from 'vitest';
import { isValidGitHubUrl, isValidCommitHash, isValidPluginName, sanitizeShellInput } from '../../src/core/validator.js';

describe('GitHub URL Validation', () => {
  describe('isValidGitHubUrl', () => {
    it('should accept valid HTTPS GitHub URL without .git extension', () => {
      expect(isValidGitHubUrl('https://github.com/owner/repo')).toBe(true);
    });

    it('should accept valid HTTPS GitHub URL with .git extension', () => {
      expect(isValidGitHubUrl('https://github.com/owner/repo.git')).toBe(true);
    });

    it('should accept GitHub URLs with hyphens in owner and repo names', () => {
      expect(isValidGitHubUrl('https://github.com/my-org/my-repo')).toBe(true);
    });

    it('should accept GitHub URLs with underscores in repo names', () => {
      expect(isValidGitHubUrl('https://github.com/nvim-lua/plenary.nvim')).toBe(true);
    });

    it('should reject HTTP (non-HTTPS) URLs', () => {
      expect(isValidGitHubUrl('http://github.com/owner/repo')).toBe(false);
    });

    it('should reject non-GitHub domains', () => {
      expect(isValidGitHubUrl('https://gitlab.com/owner/repo')).toBe(false);
      expect(isValidGitHubUrl('https://bitbucket.org/owner/repo')).toBe(false);
    });

    it('should reject SSH protocol URLs', () => {
      expect(isValidGitHubUrl('git@github.com:owner/repo.git')).toBe(false);
    });

    it('should reject URLs missing repository name', () => {
      expect(isValidGitHubUrl('https://github.com/owner')).toBe(false);
      expect(isValidGitHubUrl('https://github.com/owner/')).toBe(false);
    });

    it('should reject URLs with invalid characters', () => {
      expect(isValidGitHubUrl('https://github.com/owner/repo name')).toBe(false);
      expect(isValidGitHubUrl('https://github.com/owner/repo;rm-rf')).toBe(false);
    });

    it('should reject empty strings', () => {
      expect(isValidGitHubUrl('')).toBe(false);
    });

    it('should reject malformed URLs', () => {
      expect(isValidGitHubUrl('not-a-url')).toBe(false);
      expect(isValidGitHubUrl('github.com/owner/repo')).toBe(false);
    });
  });
});

describe('Commit Hash Validation', () => {
  describe('isValidCommitHash', () => {
    it('should accept valid 40-character SHA-1 hash (lowercase)', () => {
      expect(isValidCommitHash('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0')).toBe(true);
    });

    it('should accept valid 40-character SHA-1 hash (uppercase)', () => {
      expect(isValidCommitHash('A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0')).toBe(true);
    });

    it('should accept valid 40-character SHA-1 hash (mixed case)', () => {
      expect(isValidCommitHash('a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683')).toBe(true);
    });

    it('should accept all lowercase hexadecimal characters', () => {
      expect(isValidCommitHash('abcdef0123456789abcdef0123456789abcdef01')).toBe(true);
    });

    it('should reject 39-character hash (too short)', () => {
      expect(isValidCommitHash('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b')).toBe(false);
    });

    it('should reject 41-character hash (too long)', () => {
      expect(isValidCommitHash('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b01')).toBe(false);
    });

    it('should reject hash with non-hexadecimal characters', () => {
      expect(isValidCommitHash('g1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0')).toBe(false);
      expect(isValidCommitHash('a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9bz')).toBe(false);
    });

    it('should reject empty string', () => {
      expect(isValidCommitHash('')).toBe(false);
    });

    it('should reject short commit hashes (7 characters)', () => {
      expect(isValidCommitHash('a1b2c3d')).toBe(false);
    });

    it('should reject hash with spaces', () => {
      expect(isValidCommitHash('a1b2c3d4 e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0')).toBe(false);
    });

    it('should reject hash with special characters', () => {
      expect(isValidCommitHash('a1b2c3d4-e5f6-a7b8-c9d0-e1f2a3b4c5d6e7f8')).toBe(false);
    });
  });
});

describe('Plugin Name Validation', () => {
  describe('isValidPluginName', () => {
    it('should accept plugin name with hyphens', () => {
      expect(isValidPluginName('nvim-treesitter')).toBe(true);
    });

    it('should accept plugin name with underscores', () => {
      expect(isValidPluginName('plenary_nvim')).toBe(true);
    });

    it('should accept plugin name with numbers', () => {
      expect(isValidPluginName('plugin123')).toBe(true);
      expect(isValidPluginName('telescope2')).toBe(true);
    });

    it('should accept single character name', () => {
      expect(isValidPluginName('a')).toBe(true);
    });

    it('should accept plugin name with dots (for .nvim extension)', () => {
      expect(isValidPluginName('plenary.nvim')).toBe(true);
      expect(isValidPluginName('telescope.nvim')).toBe(true);
    });

    it('should accept 100-character name (maximum)', () => {
      const maxName = 'a'.repeat(100);
      expect(isValidPluginName(maxName)).toBe(true);
    });

    it('should reject empty string', () => {
      expect(isValidPluginName('')).toBe(false);
    });

    it('should reject name with spaces', () => {
      expect(isValidPluginName('plugin name')).toBe(false);
      expect(isValidPluginName('my plugin')).toBe(false);
    });

    it('should reject 101-character name (exceeds maximum)', () => {
      const tooLong = 'a'.repeat(101);
      expect(isValidPluginName(tooLong)).toBe(false);
    });

    it('should reject name with forward slashes', () => {
      expect(isValidPluginName('plugin/name')).toBe(false);
      expect(isValidPluginName('owner/repo')).toBe(false);
    });

    it('should reject name with special characters', () => {
      expect(isValidPluginName('plugin@name')).toBe(false);
      expect(isValidPluginName('plugin$name')).toBe(false);
      expect(isValidPluginName('plugin;name')).toBe(false);
    });

    it('should reject name starting with hyphen', () => {
      expect(isValidPluginName('-plugin')).toBe(false);
    });
  });
});

describe('Shell Input Sanitization', () => {
  describe('sanitizeShellInput', () => {
    it('should accept normal alphanumeric paths', () => {
      expect(() => sanitizeShellInput('/path/to/plugin')).not.toThrow();
      expect(() => sanitizeShellInput('plugin-name')).not.toThrow();
    });

    it('should accept URLs with allowed characters', () => {
      expect(() => sanitizeShellInput('https://github.com/owner/repo')).not.toThrow();
    });

    it('should reject input with semicolons', () => {
      expect(() => sanitizeShellInput('path; rm -rf /')).toThrow();
    });

    it('should reject input with pipes', () => {
      expect(() => sanitizeShellInput('path | cat')).toThrow();
    });

    it('should reject input with ampersands', () => {
      expect(() => sanitizeShellInput('path && rm')).toThrow();
      expect(() => sanitizeShellInput('path & rm')).toThrow();
    });

    it('should reject input with dollar signs', () => {
      expect(() => sanitizeShellInput('path$(whoami)')).toThrow();
      expect(() => sanitizeShellInput('path$VAR')).toThrow();
    });

    it('should reject input with backticks', () => {
      expect(() => sanitizeShellInput('path`whoami`')).toThrow();
    });

    it('should reject input with parentheses (subshells)', () => {
      expect(() => sanitizeShellInput('path(whoami)')).toThrow();
    });

    it('should reject input with angle brackets (redirects)', () => {
      expect(() => sanitizeShellInput('path > /dev/null')).toThrow();
      expect(() => sanitizeShellInput('path < input')).toThrow();
    });

    it('should reject input with newlines', () => {
      expect(() => sanitizeShellInput('path\nrm -rf /')).toThrow();
    });
  });
});
