import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { resolvePluginPath, expandTilde, compressTilde, getDefaultInstallDir } from '../../src/utils/paths.js';
import os from 'os';

describe('Path Resolution', () => {
  const originalPlatform = process.platform;
  const originalEnv = process.env;

  afterEach(() => {
    // Restore original platform
    Object.defineProperty(process, 'platform', {
      value: originalPlatform
    });
    process.env = originalEnv;
  });

  describe('resolvePluginPath', () => {
    it('should resolve Unix path with default install directory', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux'
      });

      const path = resolvePluginPath('plenary.nvim');
      expect(path).toContain('.local/share/nvim/necromancer/plugins/plenary.nvim');
      expect(path).not.toContain('\\'); // No backslashes on Unix
    });

    it('should resolve Windows path with default install directory', () => {
      Object.defineProperty(process, 'platform', {
        value: 'win32'
      });
      process.env.LOCALAPPDATA = 'C:\\Users\\TestUser\\AppData\\Local';

      const path = resolvePluginPath('plenary.nvim');
      expect(path).toContain('nvim\\necromancer\\plugins\\plenary.nvim');
      expect(path).toContain('AppData\\Local');
    });

    it('should resolve macOS path with default install directory', () => {
      Object.defineProperty(process, 'platform', {
        value: 'darwin'
      });

      const path = resolvePluginPath('telescope.nvim');
      expect(path).toContain('.local/share/nvim/necromancer/plugins/telescope.nvim');
    });

    it('should use custom install directory when provided', () => {
      const customDir = '/custom/nvim/plugins';
      const path = resolvePluginPath('plenary.nvim', customDir);

      expect(path).toBe('/custom/nvim/plugins/plenary.nvim');
    });

    it('should expand tilde in custom directory', () => {
      const customDir = '~/.config/nvim/plugins';
      const path = resolvePluginPath('telescope.nvim', customDir);

      expect(path).not.toContain('~');
      expect(path).toContain(os.homedir());
      expect(path).toContain('telescope.nvim');
    });

    it('should handle plugin names with dots', () => {
      const path = resolvePluginPath('plenary.nvim');
      expect(path).toContain('plenary.nvim');
    });

    it('should handle plugin names with hyphens', () => {
      const path = resolvePluginPath('nvim-treesitter');
      expect(path).toContain('nvim-treesitter');
    });
  });

  describe('expandTilde', () => {
    it('should expand ~ to home directory', () => {
      const expanded = expandTilde('~/test/path');
      expect(expanded).toBe(`${os.homedir()}/test/path`);
    });

    it('should not modify paths without tilde', () => {
      const path = '/absolute/path/test';
      expect(expandTilde(path)).toBe(path);
    });

    it('should only expand leading tilde', () => {
      const path = '/path/with/~/in/middle';
      expect(expandTilde(path)).toBe(path);
    });

    it('should expand tilde with trailing slash', () => {
      const expanded = expandTilde('~/');
      expect(expanded).toBe(`${os.homedir()}/`);
    });
  });

  describe('compressTilde', () => {
    it('should compress home directory to tilde', () => {
      const homeDir = os.homedir();
      const compressed = compressTilde(`${homeDir}/test/path`);
      expect(compressed).toMatch(/^~[\/\\]test[\/\\]path$/);
    });

    it('should not modify paths outside home directory', () => {
      const path = '/opt/nvim/plugins';
      expect(compressTilde(path)).toBe(path);
    });

    it('should compress home directory itself to tilde', () => {
      const homeDir = os.homedir();
      const compressed = compressTilde(homeDir);
      expect(compressed).toBe('~');
    });

    it('should handle normalized paths', () => {
      const homeDir = os.homedir();
      const pathWithDots = `${homeDir}/test/../test/path`;
      const compressed = compressTilde(pathWithDots);
      expect(compressed).toMatch(/^~[\/\\]test[\/\\]path$/);
    });

    it('should be reversible with expandTilde', () => {
      const homeDir = os.homedir();
      const originalPath = `${homeDir}/.local/share/nvim/plugins`;
      const compressed = compressTilde(originalPath);
      const expanded = expandTilde(compressed);
      expect(expanded).toBe(originalPath);
    });
  });

  describe('getDefaultInstallDir', () => {
    it('should return Unix default on Linux', () => {
      Object.defineProperty(process, 'platform', {
        value: 'linux'
      });

      const dir = getDefaultInstallDir();
      expect(dir).toContain('.local/share/nvim/necromancer/plugins');
    });

    it('should return Unix default on macOS', () => {
      Object.defineProperty(process, 'platform', {
        value: 'darwin'
      });

      const dir = getDefaultInstallDir();
      expect(dir).toContain('.local/share/nvim/necromancer/plugins');
    });

    it('should return Windows default on win32', () => {
      Object.defineProperty(process, 'platform', {
        value: 'win32'
      });
      process.env.LOCALAPPDATA = 'C:\\Users\\TestUser\\AppData\\Local';

      const dir = getDefaultInstallDir();
      expect(dir).toContain('AppData\\Local\\nvim\\necromancer\\plugins');
    });

    it('should throw error on Windows if LOCALAPPDATA not set', () => {
      Object.defineProperty(process, 'platform', {
        value: 'win32'
      });
      delete process.env.LOCALAPPDATA;

      expect(() => getDefaultInstallDir()).toThrow(/LOCALAPPDATA/);
    });
  });
});
