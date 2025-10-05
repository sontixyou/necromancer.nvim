import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { execSync } from 'child_process';
import type { ConfigFile } from '../../src/models/config-file.js';
import type { LockFile } from '../../src/models/lockfile.js';

/**
 * Integration tests for clean command
 *
 * T037: Remove plugin and clean (Scenario 4)
 */

describe('Clean Command Integration Tests', () => {
  let testDir: string;
  let testRepoPath: string;
  let configPath: string;
  let lockPath: string;
  let installDir: string;
  let commit1: string;
  let commit2: string;
  let commit3: string;

  beforeEach(() => {
    // Create temporary test directory
    testDir = mkdtempSync(join(tmpdir(), 'necromancer-test-'));
    testRepoPath = join(testDir, 'test-repo');
    configPath = join(testDir, '.necromancer.json');
    lockPath = join(testDir, '.necromancer.lock');
    installDir = join(testDir, 'plugins');

    // Create install directory
    mkdirSync(installDir, { recursive: true });

    // Create a test git repository with known commits
    mkdirSync(testRepoPath);
    execSync('git init', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git config user.email "test@test.com"', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git config user.name "Test User"', { cwd: testRepoPath, stdio: 'pipe' });

    // Create commits
    writeFileSync(join(testRepoPath, 'file1.txt'), 'Content 1\n');
    execSync('git add file1.txt', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Commit 1"', { cwd: testRepoPath, stdio: 'pipe' });
    commit1 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();

    writeFileSync(join(testRepoPath, 'file2.txt'), 'Content 2\n');
    execSync('git add file2.txt', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Commit 2"', { cwd: testRepoPath, stdio: 'pipe' });
    commit2 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();

    writeFileSync(join(testRepoPath, 'file3.txt'), 'Content 3\n');
    execSync('git add file3.txt', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Commit 3"', { cwd: testRepoPath, stdio: 'pipe' });
    commit3 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();
  });

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  describe('Remove plugin and clean', () => {
    it('should remove orphaned plugins with --force flag', async () => {
      // Install 3 plugins
      const initialConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin-1',
            repo: testRepoPath,
            commit: commit1
          },
          {
            name: 'test-plugin-2',
            repo: testRepoPath,
            commit: commit2
          },
          {
            name: 'test-plugin-3',
            repo: testRepoPath,
            commit: commit3
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(initialConfig, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Verify all 3 plugins installed
      expect(existsSync(join(installDir, 'test-plugin-1'))).toBe(true);
      expect(existsSync(join(installDir, 'test-plugin-2'))).toBe(true);
      expect(existsSync(join(installDir, 'test-plugin-3'))).toBe(true);

      // Remove plugin-2 from config
      const updatedConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin-1',
            repo: testRepoPath,
            commit: commit1
          },
          {
            name: 'test-plugin-3',
            repo: testRepoPath,
            commit: commit3
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2));

      // Run clean with --force
      const { clean } = await import('../../src/cli/commands/clean.js');
      const exitCode = await clean({ config: configPath, force: true });

      // Verify exit code
      expect(exitCode).toBe(0);

      // Verify plugin-2 removed
      expect(existsSync(join(installDir, 'test-plugin-2'))).toBe(false);

      // Verify other plugins still exist
      expect(existsSync(join(installDir, 'test-plugin-1'))).toBe(true);
      expect(existsSync(join(installDir, 'test-plugin-3'))).toBe(true);

      // Verify lock file updated
      const lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins).toHaveLength(2);
      expect(lockFile.plugins.find(p => p.name === 'test-plugin-1')).toBeDefined();
      expect(lockFile.plugins.find(p => p.name === 'test-plugin-3')).toBeDefined();
      expect(lockFile.plugins.find(p => p.name === 'test-plugin-2')).toBeUndefined();
    });

    it('should show what would be removed with --dry-run flag', async () => {
      // Install 2 plugins
      const initialConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin-1',
            repo: testRepoPath,
            commit: commit1
          },
          {
            name: 'test-plugin-2',
            repo: testRepoPath,
            commit: commit2
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(initialConfig, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Remove plugin-1 from config
      const updatedConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin-2',
            repo: testRepoPath,
            commit: commit2
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2));

      // Run clean with --dry-run
      const { clean } = await import('../../src/cli/commands/clean.js');
      const exitCode = await clean({ config: configPath, dryRun: true });

      // Verify exit code (success even in dry-run)
      expect(exitCode).toBe(0);

      // Verify nothing actually removed
      expect(existsSync(join(installDir, 'test-plugin-1'))).toBe(true);
      expect(existsSync(join(installDir, 'test-plugin-2'))).toBe(true);

      // Verify lock file NOT updated
      const lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins).toHaveLength(2);
    });

    it('should return success when no orphaned plugins exist', async () => {
      // Install 1 plugin
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

      // Run clean (no orphaned plugins)
      const { clean } = await import('../../src/cli/commands/clean.js');
      const exitCode = await clean({ config: configPath, force: true });

      // Verify exit code
      expect(exitCode).toBe(0);

      // Verify plugin still exists
      expect(existsSync(join(installDir, 'test-plugin'))).toBe(true);

      // Verify lock file unchanged
      const lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins).toHaveLength(1);
    });
  });
});
