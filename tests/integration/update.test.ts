import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { execSync } from 'child_process';
import type { ConfigFile } from '../../src/models/config-file.js';
import type { LockFile } from '../../src/models/lockfile.js';

/**
 * Integration tests for update command
 *
 * T035: Update plugin versions (Scenario 2)
 */

describe('Update Command Integration Tests', () => {
  let testDir: string;
  let testRepoPath: string;
  let configPath: string;
  let lockPath: string;
  let installDir: string;
  let commit1: string;
  let commit2: string;

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

    // Create first commit
    writeFileSync(join(testRepoPath, 'README.md'), '# Test Plugin v1\n');
    execSync('git add README.md', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Version 1"', { cwd: testRepoPath, stdio: 'pipe' });
    commit1 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();

    // Create second commit
    writeFileSync(join(testRepoPath, 'README.md'), '# Test Plugin v2\n');
    execSync('git add README.md', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Version 2"', { cwd: testRepoPath, stdio: 'pipe' });
    commit2 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();
  });

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  describe('Update plugin versions', () => {
    it('should update plugin to new commit without re-cloning', async () => {
      // Install plugin at commit1
      const initialConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: commit1
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(initialConfig, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Verify initial installation
      const pluginPath = join(installDir, 'test-plugin');
      expect(existsSync(pluginPath)).toBe(true);

      let currentCommit = execSync('git rev-parse HEAD', {
        cwd: pluginPath,
        encoding: 'utf-8'
      }).trim();
      expect(currentCommit).toBe(commit1);

      // Check initial lock file
      let lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins[0]?.commit).toBe(commit1);

      // Update config to commit2
      const updatedConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin',
            repo: testRepoPath,
            commit: commit2
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2));

      // Run update command
      const { update } = await import('../../src/cli/commands/update.js');
      const exitCode = await update({ config: configPath });

      // Verify exit code
      expect(exitCode).toBe(0);

      // Verify plugin updated to commit2
      currentCommit = execSync('git rev-parse HEAD', {
        cwd: pluginPath,
        encoding: 'utf-8'
      }).trim();
      expect(currentCommit).toBe(commit2);

      // Verify lock file updated
      lockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins[0]?.commit).toBe(commit2);

      // Verify still a valid git repo
      expect(existsSync(join(pluginPath, '.git'))).toBe(true);

      // Verify README content changed (shows it's actually commit2)
      const readmeContent = readFileSync(join(pluginPath, 'README.md'), 'utf-8');
      expect(readmeContent).toBe('# Test Plugin v2\n');
    });

    it('should skip plugins already at correct commit', async () => {
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
            commit: commit2
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(config, null, 2));

      const { install } = await import('../../src/cli/commands/install.js');
      await install({ config: configPath });

      // Update only plugin-1 to commit2 in config
      const updatedConfig: ConfigFile = {
        plugins: [
          {
            name: 'test-plugin-1',
            repo: testRepoPath,
            commit: commit2  // Changed
          },
          {
            name: 'test-plugin-2',
            repo: testRepoPath,
            commit: commit2  // Same as before
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2));

      // Run update
      const { update } = await import('../../src/cli/commands/update.js');
      const exitCode = await update({ config: configPath });

      // Verify exit code
      expect(exitCode).toBe(0);

      // Verify plugin-1 updated
      const plugin1Path = join(installDir, 'test-plugin-1');
      const plugin1Commit = execSync('git rev-parse HEAD', {
        cwd: plugin1Path,
        encoding: 'utf-8'
      }).trim();
      expect(plugin1Commit).toBe(commit2);

      // Verify plugin-2 still at commit2 (not re-cloned)
      const plugin2Path = join(installDir, 'test-plugin-2');
      const plugin2Commit = execSync('git rev-parse HEAD', {
        cwd: plugin2Path,
        encoding: 'utf-8'
      }).trim();
      expect(plugin2Commit).toBe(commit2);

      // Verify both in lock file
      const lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins).toHaveLength(2);
      expect(lockFile.plugins.find(p => p.name === 'test-plugin-1')?.commit).toBe(commit2);
      expect(lockFile.plugins.find(p => p.name === 'test-plugin-2')?.commit).toBe(commit2);
    });
  });
});
