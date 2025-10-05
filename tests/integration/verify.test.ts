import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, existsSync, mkdirSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { execSync } from 'child_process';
import type { ConfigFile } from '../../src/models/config-file.js';

/**
 * Integration tests for verify command
 *
 * T038: Verify and repair (Scenario 5)
 */

describe('Verify Command Integration Tests', () => {
  let testDir: string;
  let testRepoPath: string;
  let configPath: string;
  let lockPath: string;
  let installDir: string;
  let commit1: string;

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

    // Create commit
    writeFileSync(join(testRepoPath, 'README.md'), '# Test Plugin\n');
    execSync('git add README.md', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Initial commit"', { cwd: testRepoPath, stdio: 'pipe' });
    commit1 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();
  });

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  describe('Verify and repair', () => {
    it('should detect corrupted installation and repair with --fix', async () => {
      // Install plugin
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: commit1
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Verify plugin installed correctly
      const pluginPath = join(installDir, 'test-plugin');
      expect(existsSync(pluginPath)).toBe(true);
      expect(existsSync(join(pluginPath, '.git'))).toBe(true);

      // Corrupt the plugin (delete .git directory)
      rmSync(join(pluginPath, '.git'), { recursive: true, force: true });

      // Verify should detect corruption
      const { verify } = await import('../../src/cli/commands/verify.js');
      const verifyExitCode = await verify({ config: configPath });

      // Should return exit code 2 (issues found)
      expect(verifyExitCode).toBe(2);

      // Verify with --fix should repair
      const fixExitCode = await verify({ config: configPath, fix: true });

      // Should return exit code 0 (success)
      expect(fixExitCode).toBe(0);

      // Verify plugin restored
      expect(existsSync(join(pluginPath, '.git'))).toBe(true);

      // Verify correct commit
      const currentCommit = execSync('git rev-parse HEAD', {
        cwd: pluginPath,
        encoding: 'utf-8'
      }).trim();
      expect(currentCommit).toBe(commit1);

      // Verify should now pass
      const finalVerifyExitCode = await verify({ config: configPath });
      expect(finalVerifyExitCode).toBe(0);
    });

    it('should verify all plugins successfully when no corruption', async () => {
      // Install 2 plugins
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin-1',
            repo: testRepoPath,
            commit: commit1
          },
          {
            name: 'test-plugin-2',
            repo: testRepoPath,
            commit: commit1
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Verify should pass
      const { verify } = await import('../../src/cli/commands/verify.js');
      const exitCode = await verify({ config: configPath });

      // Should return exit code 0 (success)
      expect(exitCode).toBe(0);
    });

    it('should detect missing plugin directory', async () => {
      // Install plugin
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: commit1
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Delete entire plugin directory
      const pluginPath = join(installDir, 'test-plugin');
      rmSync(pluginPath, { recursive: true, force: true });

      // Verify should detect missing directory
      const { verify } = await import('../../src/cli/commands/verify.js');
      const verifyExitCode = await verify({ config: configPath });

      // Should return exit code 2 (issues found)
      expect(verifyExitCode).toBe(2);

      // Verify with --fix should repair
      const fixExitCode = await verify({ config: configPath, fix: true });

      // Should return exit code 0 (success)
      expect(fixExitCode).toBe(0);

      // Verify plugin restored
      expect(existsSync(pluginPath)).toBe(true);
      expect(existsSync(join(pluginPath, '.git'))).toBe(true);
    });

    it('should return error code when no lock file exists', async () => {
      // Create config without installing
      const config: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: commit1
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      // Verify without lock file
      const { verify } = await import('../../src/cli/commands/verify.js');
      const exitCode = await verify({ config: configPath });

      // Should return exit code 2 (no lock file)
      expect(exitCode).toBe(2);
    });
  });
});
