import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, existsSync, mkdirSync, writeFileSync, readFileSync, readdirSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { execSync } from 'child_process';
import type { ConfigFile } from '../../src/models/config-file.js';

/**
 * Integration tests for error handling
 *
 * T039: Invalid commit error (Scenario 6)
 * T040: Invalid config error (Scenario 7)
 */

describe('Error Handling Integration Tests', () => {
  let testDir: string;
  let testRepoPath: string;
  let configPath: string;
  let lockPath: string;
  let installDir: string;
  let validCommit: string;

  beforeEach(() => {
    // Create temporary test directory
    testDir = mkdtempSync(join(tmpdir(), 'necromancer-test-'));
    testRepoPath = join(testDir, 'test-repo');
    configPath = join(testDir, '.necromancer.json');
    lockPath = join(testDir, '.necromancer.lock');
    installDir = join(testDir, 'plugins');

    // Create install directory
    mkdirSync(installDir, { recursive: true });

    // Create a test git repository
    mkdirSync(testRepoPath);
    execSync('git init', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git config user.email "test@test.com"', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git config user.name "Test User"', { cwd: testRepoPath, stdio: 'pipe' });

    // Create a valid commit
    writeFileSync(join(testRepoPath, 'README.md'), '# Test\n');
    execSync('git add README.md', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Initial"', { cwd: testRepoPath, stdio: 'pipe' });
    validCommit = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();
  });

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  /**
   * T039: Invalid commit error (Scenario 6)
   */
  describe('Invalid commit hash', () => {
    it('should fail gracefully with non-existent commit hash', async () => {
      // Create config with invalid commit (all zeros is valid format but doesn't exist)
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: '0000000000000000000000000000000000000000'
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 2 (partial failure)
      expect(exitCode).toBe(2);

      // Lock file should not contain the failed plugin
      // (lock file is only updated for successful installations)
      const lockFileExists = existsSync(lockPath);

      if (lockFileExists) {
        const lockContent = readFileSync(lockPath, 'utf-8');
        const lockFile = JSON.parse(lockContent);
        const failedPlugin = lockFile.plugins.find((p: { name: string }) => p.name === 'test-plugin');
        // Failed plugin should not be in lock file
        expect(failedPlugin).toBeUndefined();
      } else {
        // Or lock file doesn't exist at all (which is also acceptable)
        expect(lockFileExists).toBe(false);
      }
    });

    it('should install valid plugins and fail only invalid ones', async () => {
      // Create config with 1 valid and 1 invalid commit
      const config: ConfigFile = {
        plugins: [
          {
            name: 'valid-plugin',
            repo: testRepoPath,
            commit: validCommit
          },
          {
            name: 'invalid-plugin',
            repo: testRepoPath,
            commit: '0000000000000000000000000000000000000000'
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 2 (partial failure)
      expect(exitCode).toBe(2);

      // Verify valid plugin installed
      const validPluginPath = join(installDir, 'valid-plugin');
      expect(existsSync(validPluginPath)).toBe(true);
      expect(existsSync(join(validPluginPath, '.git'))).toBe(true);

      const currentCommit = execSync('git rev-parse HEAD', {
        cwd: validPluginPath,
        encoding: 'utf-8'
      }).trim();
      expect(currentCommit).toBe(validCommit);
    });
  });

  /**
   * T040: Invalid config error (Scenario 7)
   */
  describe('Invalid configuration', () => {
    it('should fail with duplicate plugin names', async () => {
      // Create config with duplicate plugin names
      const config: ConfigFile = {
        plugins: [
          {
            name: 'duplicate-plugin',
            repo: testRepoPath,
            commit: validCommit
          },
          {
            name: 'duplicate-plugin',  // Duplicate name
            repo: testRepoPath,
            commit: '1111111111111111111111111111111111111111'
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 1 (configuration error)
      expect(exitCode).toBe(1);

      // Verify no plugins installed (validation happens before git operations)
      const pluginDirs = existsSync(installDir) ? readdirSync(installDir) : [];
      expect(pluginDirs.length).toBe(0);

      // Verify lock file not created
      expect(existsSync(lockPath)).toBe(false);
    });

    it('should fail with invalid GitHub URL', async () => {
      // Create config with invalid URL
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: 'http://example.com/repo',  // Invalid: not HTTPS GitHub
            commit: validCommit
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 1 (configuration error)
      expect(exitCode).toBe(1);

      // Verify no plugins installed
      const pluginDirs = existsSync(installDir) ? readdirSync(installDir) : [];
      expect(pluginDirs.length).toBe(0);
    });

    it('should fail with invalid commit hash format', async () => {
      // Create config with invalid commit hash (too short)
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: 'abc123'  // Invalid: too short
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 1 (configuration error)
      expect(exitCode).toBe(1);

      // Verify no plugins installed
      const pluginDirs = existsSync(installDir) ? readdirSync(installDir) : [];
      expect(pluginDirs.length).toBe(0);
    });

    it('should fail with invalid plugin name', async () => {
      // Create config with invalid plugin name (contains slash)
      const config: ConfigFile = {
        plugins: [
          {
            name: 'invalid/plugin',  // Invalid: contains slash
            repo: testRepoPath,
            commit: validCommit
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 1 (configuration error)
      expect(exitCode).toBe(1);

      // Verify no plugins installed
      const pluginDirs = existsSync(installDir) ? readdirSync(installDir) : [];
      expect(pluginDirs.length).toBe(0);
    });

    it('should fail with empty plugins array', async () => {
      // Create config with empty plugins array
      const config: ConfigFile = {
        plugins: [],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Attempt installation
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Should return exit code 1 (configuration error)
      expect(exitCode).toBe(1);

      // Verify no lock file created
      expect(existsSync(lockPath)).toBe(false);
    });
  });
});
