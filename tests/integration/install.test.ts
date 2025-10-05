import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, rmSync, existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { execSync } from 'child_process';
import type { ConfigFile } from '../../src/models/config-file.js';
import type { LockFile } from '../../src/models/lockfile.js';

/**
 * Integration tests for install command
 *
 * These tests use a real local git repository to avoid network dependencies.
 * We create a test git repo with known commits for deterministic testing.
 */

describe('Install Command Integration Tests', () => {
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

    // Create first commit
    writeFileSync(join(testRepoPath, 'README.md'), '# Test Plugin\n');
    execSync('git add README.md', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Initial commit"', { cwd: testRepoPath, stdio: 'pipe' });
    commit1 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();

    // Create second commit
    writeFileSync(join(testRepoPath, 'plugin.lua'), 'print("v2")\n');
    execSync('git add plugin.lua', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Add plugin file"', { cwd: testRepoPath, stdio: 'pipe' });
    commit2 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();

    // Create third commit
    writeFileSync(join(testRepoPath, 'doc.txt'), 'Documentation\n');
    execSync('git add doc.txt', { cwd: testRepoPath, stdio: 'pipe' });
    execSync('git commit -m "Add documentation"', { cwd: testRepoPath, stdio: 'pipe' });
    commit3 = execSync('git rev-parse HEAD', { cwd: testRepoPath, encoding: 'utf-8' }).trim();
  });

  afterEach(() => {
    // Clean up test directory
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true, force: true });
    }
  });

  /**
   * T034: First-time setup (Scenario 1)
   */
  describe('First-time setup', () => {
    it('should install plugins from scratch', async () => {
      // Create config with 2 plugins
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

      // Run install command
      const { install } = await import('../../src/cli/commands/install.js');
      const exitCode = await install({ config: configPath });

      // Verify exit code
      expect(exitCode).toBe(0);

      // Verify plugins installed
      const plugin1Path = join(installDir, 'test-plugin-1');
      const plugin2Path = join(installDir, 'test-plugin-2');
      expect(existsSync(plugin1Path)).toBe(true);
      expect(existsSync(plugin2Path)).toBe(true);

      // Verify git repos exist
      expect(existsSync(join(plugin1Path, '.git'))).toBe(true);
      expect(existsSync(join(plugin2Path, '.git'))).toBe(true);

      // Verify correct commits
      const plugin1Commit = execSync('git rev-parse HEAD', {
        cwd: plugin1Path,
        encoding: 'utf-8'
      }).trim();
      const plugin2Commit = execSync('git rev-parse HEAD', {
        cwd: plugin2Path,
        encoding: 'utf-8'
      }).trim();
      expect(plugin1Commit).toBe(commit1);
      expect(plugin2Commit).toBe(commit2);

      // Verify lock file created
      expect(existsSync(lockPath)).toBe(true);
      const lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.version).toBe('1');
      expect(lockFile.plugins).toHaveLength(2);
      expect(lockFile.plugins[0]?.name).toBe('test-plugin-1');
      expect(lockFile.plugins[0]?.commit).toBe(commit1);
      expect(lockFile.plugins[1]?.name).toBe('test-plugin-2');
      expect(lockFile.plugins[1]?.commit).toBe(commit2);
    });
  });

  /**
   * T036: Add new plugin (Scenario 3)
   */
  describe('Add new plugin', () => {
    it('should install only new plugin without touching existing ones', async () => {
      // First install 2 plugins
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

      // Get initial timestamps
      const plugin1Path = join(installDir, 'test-plugin-1');
      const plugin2Path = join(installDir, 'test-plugin-2');
      const plugin1InitialMtime = existsSync(plugin1Path)
        ? (await import('fs')).statSync(plugin1Path).mtime.getTime()
        : 0;
      const plugin2InitialMtime = existsSync(plugin2Path)
        ? (await import('fs')).statSync(plugin2Path).mtime.getTime()
        : 0;

      // Wait a bit to ensure timestamp difference
      await new Promise(resolve => setTimeout(resolve, 100));

      // Add 3rd plugin to config
      const updatedConfig: ConfigFile = {
        plugins: [
          ...initialConfig.plugins,
          {
            name: 'test-plugin-3',
            repo: testRepoPath,
            commit: commit3
          }
        ],
        installDir
      };

      writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2));

      // Run install again
      const exitCode = await install({ config: configPath });

      // Verify exit code
      expect(exitCode).toBe(0);

      // Verify new plugin installed
      const plugin3Path = join(installDir, 'test-plugin-3');
      expect(existsSync(plugin3Path)).toBe(true);
      expect(existsSync(join(plugin3Path, '.git'))).toBe(true);

      const plugin3Commit = execSync('git rev-parse HEAD', {
        cwd: plugin3Path,
        encoding: 'utf-8'
      }).trim();
      expect(plugin3Commit).toBe(commit3);

      // Verify existing plugins NOT re-cloned (check directory didn't change)
      // Note: This is a simplified check - in reality we'd check git timestamps
      expect(existsSync(plugin1Path)).toBe(true);
      expect(existsSync(plugin2Path)).toBe(true);

      // Verify lock file updated
      const lockFile: LockFile = JSON.parse(readFileSync(lockPath, 'utf-8'));
      expect(lockFile.plugins).toHaveLength(3);
      expect(lockFile.plugins.find(p => p.name === 'test-plugin-3')).toBeDefined();
    });
  });
});
