import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { writeFileSync, unlinkSync, mkdirSync, rmdirSync } from 'fs';
import { join } from 'path';
import { parseConfigFile, validateConfig } from '../../src/core/config.js';

describe('Config File Parsing', () => {
  const testDir = join(process.cwd(), 'test-tmp');
  const configPath = join(testDir, 'test-config.json');

  beforeEach(() => {
    mkdirSync(testDir, { recursive: true });
  });

  afterEach(() => {
    try {
      unlinkSync(configPath);
    } catch {
      // File might not exist
    }
    try {
      rmdirSync(testDir);
    } catch {
      // Directory might not be empty
    }
  });

  describe('parseConfigFile', () => {
    it('should parse valid JSON with 2 plugins', () => {
      const validConfig = {
        plugins: [
          {
            name: 'plenary.nvim',
            repo: 'https://github.com/nvim-lua/plenary.nvim',
            commit: 'a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683'
          },
          {
            name: 'telescope.nvim',
            repo: 'https://github.com/nvim-telescope/telescope.nvim',
            commit: '0dfbf5e48e8551212c2a9f1c5614d008f4e86eba'
          }
        ]
      };

      writeFileSync(configPath, JSON.stringify(validConfig, null, 2));
      const config = parseConfigFile(configPath);

      expect(config.plugins).toHaveLength(2);
      expect(config.plugins[0]?.name).toBe('plenary.nvim');
      expect(config.plugins[1]?.name).toBe('telescope.nvim');
    });

    it('should parse config with custom installDir', () => {
      const configWithInstallDir = {
        plugins: [
          {
            name: 'plugin1',
            repo: 'https://github.com/owner/plugin1',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          }
        ],
        installDir: '~/.config/nvim/plugins'
      };

      writeFileSync(configPath, JSON.stringify(configWithInstallDir, null, 2));
      const config = parseConfigFile(configPath);

      expect(config.installDir).toBe('~/.config/nvim/plugins');
    });

    it('should throw error for invalid JSON syntax', () => {
      writeFileSync(configPath, '{invalid json}');
      expect(() => parseConfigFile(configPath)).toThrow();
    });

    it('should throw error for missing file', () => {
      const nonExistentPath = join(testDir, 'does-not-exist.json');
      expect(() => parseConfigFile(nonExistentPath)).toThrow();
    });
  });

  describe('validateConfig', () => {
    it('should accept valid config with required fields', () => {
      const validConfig = {
        plugins: [
          {
            name: 'plugin1',
            repo: 'https://github.com/owner/plugin1',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          }
        ]
      };

      expect(() => validateConfig(validConfig)).not.toThrow();
    });

    it('should throw error for empty plugins array', () => {
      const emptyPluginsConfig = {
        plugins: []
      };

      expect(() => validateConfig(emptyPluginsConfig)).toThrow(/plugins array must not be empty/i);
    });

    it('should throw error for duplicate plugin names', () => {
      const duplicateConfig = {
        plugins: [
          {
            name: 'plenary.nvim',
            repo: 'https://github.com/nvim-lua/plenary.nvim',
            commit: 'a3e3bc82a3f95c5ed0d7201546d5d2c19b20d683'
          },
          {
            name: 'plenary.nvim',
            repo: 'https://github.com/nvim-lua/plenary.nvim',
            commit: 'b1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          }
        ]
      };

      expect(() => validateConfig(duplicateConfig)).toThrow(/duplicate plugin name/i);
    });

    it('should throw error for missing name field', () => {
      const missingName = {
        plugins: [
          {
            repo: 'https://github.com/owner/plugin1',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          } as any
        ]
      };

      expect(() => validateConfig(missingName)).toThrow(/missing.*name/i);
    });

    it('should throw error for missing repo field', () => {
      const missingRepo = {
        plugins: [
          {
            name: 'plugin1',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          } as any
        ]
      };

      expect(() => validateConfig(missingRepo)).toThrow(/missing.*repo/i);
    });

    it('should throw error for missing commit field', () => {
      const missingCommit = {
        plugins: [
          {
            name: 'plugin1',
            repo: 'https://github.com/owner/plugin1'
          } as any
        ]
      };

      expect(() => validateConfig(missingCommit)).toThrow(/missing.*commit/i);
    });

    it('should throw error for invalid GitHub URL', () => {
      const invalidUrl = {
        plugins: [
          {
            name: 'plugin1',
            repo: 'https://gitlab.com/owner/plugin1',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          }
        ]
      };

      expect(() => validateConfig(invalidUrl)).toThrow(/invalid.*url/i);
    });

    it('should throw error for invalid commit hash', () => {
      const invalidCommit = {
        plugins: [
          {
            name: 'plugin1',
            repo: 'https://github.com/owner/plugin1',
            commit: 'invalid-commit-hash'
          }
        ]
      };

      expect(() => validateConfig(invalidCommit)).toThrow(/invalid.*commit/i);
    });

    it('should throw error for invalid plugin name', () => {
      const invalidName = {
        plugins: [
          {
            name: 'plugin name with spaces',
            repo: 'https://github.com/owner/plugin1',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0'
          }
        ]
      };

      expect(() => validateConfig(invalidName)).toThrow(/invalid.*name/i);
    });

    it('should accept valid dependencies', () => {
      const validDependencies = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: ['plugin-b']
          },
          {
            name: 'plugin-b',
            repo: 'https://github.com/owner/plugin-b',
            commit: 'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0'
          }
        ]
      };

      expect(() => validateConfig(validDependencies)).not.toThrow();
    });

    it('should accept empty dependencies array', () => {
      const emptyDependencies = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: []
          }
        ]
      };

      expect(() => validateConfig(emptyDependencies)).not.toThrow();
    });

    it('should throw error for non-array dependencies', () => {
      const invalidDependencies = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: 'not-an-array'
          } as any
        ]
      };

      expect(() => validateConfig(invalidDependencies)).toThrow(/dependencies.*must be an array/i);
    });

    it('should throw error for non-string dependency names', () => {
      const invalidDepNames = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: [123, 'valid-name']
          } as any
        ]
      };

      expect(() => validateConfig(invalidDepNames)).toThrow(/dependencies.*must be an array of strings/i);
    });

    it('should throw error for invalid dependency names', () => {
      const invalidDepName = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: ['invalid name with spaces']
          }
        ]
      };

      expect(() => validateConfig(invalidDepName)).toThrow(/invalid dependency name/i);
    });

    it('should throw error for missing dependencies', () => {
      const missingDep = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: ['non-existent-plugin']
          }
        ]
      };

      expect(() => validateConfig(missingDep)).toThrow(/depends on.*not defined/i);
    });

    it('should throw error for circular dependencies', () => {
      const circularDeps = {
        plugins: [
          {
            name: 'plugin-a',
            repo: 'https://github.com/owner/plugin-a',
            commit: 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0',
            dependencies: ['plugin-b']
          },
          {
            name: 'plugin-b',
            repo: 'https://github.com/owner/plugin-b',
            commit: 'b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0',
            dependencies: ['plugin-a']
          }
        ]
      };

      expect(() => validateConfig(circularDeps)).toThrow(/circular dependency detected/i);
    });
  });
});
