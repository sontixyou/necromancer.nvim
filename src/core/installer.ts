import { existsSync, rmSync } from 'fs';
import type { PluginDefinition, InstalledPlugin, InstallationStatus } from '../models/plugin.js';
import { gitClone, gitCheckout, getCurrentCommit } from './git.js';
import { resolvePluginPath } from '../utils/paths.js';
import { GitError } from '../utils/errors.js';

/**
 * Verify that a plugin installation is valid and uncorrupted
 * @param installed - Installed plugin information
 * @returns true if installation is valid, false if corrupted
 */
export function verifyInstallation(installed: InstalledPlugin): boolean {
  try {
    // Check if directory exists
    if (!existsSync(installed.path)) {
      return false;
    }

    // Check if it's a valid git repository by trying to get current commit
    const currentCommit = getCurrentCommit(installed.path);

    // If we can get the commit, the git repo is valid
    return currentCommit.length === 40;
  } catch (error) {
    // Any error means the installation is corrupted
    return false;
  }
}

/**
 * Repair a corrupted plugin installation by re-cloning
 * @param def - Plugin definition to repair
 * @param targetPath - Full path to plugin directory
 * @throws GitError if repair fails
 */
export function repairPlugin(def: PluginDefinition, targetPath: string): void {
  // Remove corrupted installation if it exists
  if (existsSync(targetPath)) {
    try {
      rmSync(targetPath, { recursive: true, force: true });
    } catch (error) {
      throw new GitError(`Failed to remove corrupted plugin directory: ${(error as Error).message}`);
    }
  }

  // Clone fresh copy
  gitClone(def.repo, targetPath);

  // Checkout the specified commit
  gitCheckout(targetPath, def.commit);
}

/**
 * Update an existing plugin to a new commit
 * @param def - Plugin definition with new commit
 * @param installed - Currently installed plugin information
 * @returns Installation status
 */
export function updatePlugin(def: PluginDefinition, installed: InstalledPlugin): InstallationStatus {
  try {
    // Verify current installation is not corrupted
    if (!verifyInstallation(installed)) {
      // If corrupted, repair it
      repairPlugin(def, installed.path);

      return {
        plugin: def,
        status: 'updated',
        message: `Repaired and updated ${def.name} to commit ${def.commit.substring(0, 8)}`
      };
    }

    // Get current commit
    const currentCommit = getCurrentCommit(installed.path);

    // Check if already at target commit
    if (currentCommit === def.commit) {
      return {
        plugin: def,
        status: 'skipped',
        message: `${def.name} already at commit ${def.commit.substring(0, 8)}`
      };
    }

    // Checkout new commit
    gitCheckout(installed.path, def.commit);

    return {
      plugin: def,
      status: 'updated',
      message: `Updated ${def.name} from ${currentCommit.substring(0, 8)} to ${def.commit.substring(0, 8)}`
    };
  } catch (error) {
    return {
      plugin: def,
      status: 'failed',
      message: `Failed to update ${def.name}`,
      error: error as Error
    };
  }
}

/**
 * Install a new plugin
 * @param def - Plugin definition to install
 * @param installDir - Installation directory (optional, uses default if not provided)
 * @returns Installation status
 */
export function installPlugin(def: PluginDefinition, installDir?: string): InstallationStatus {
  try {
    const targetPath = resolvePluginPath(def.name, installDir);

    // Check if plugin directory already exists
    if (existsSync(targetPath)) {
      // Create minimal InstalledPlugin for verification
      const installed: InstalledPlugin = {
        name: def.name,
        repo: def.repo,
        commit: def.commit,
        installedAt: new Date().toISOString(),
        path: targetPath
      };

      // Verify and potentially repair existing installation
      if (!verifyInstallation(installed)) {
        repairPlugin(def, targetPath);

        return {
          plugin: def,
          status: 'success',
          message: `Installed ${def.name} at commit ${def.commit.substring(0, 8)} (repaired corrupted installation)`
        };
      }

      // Check current commit
      const currentCommit = getCurrentCommit(targetPath);

      if (currentCommit === def.commit) {
        return {
          plugin: def,
          status: 'skipped',
          message: `${def.name} already installed at commit ${def.commit.substring(0, 8)}`
        };
      }

      // Update to new commit
      gitCheckout(targetPath, def.commit);

      return {
        plugin: def,
        status: 'updated',
        message: `Updated ${def.name} from ${currentCommit.substring(0, 8)} to ${def.commit.substring(0, 8)}`
      };
    }

    // New installation - clone repository
    gitClone(def.repo, targetPath);

    // Checkout specified commit
    gitCheckout(targetPath, def.commit);

    return {
      plugin: def,
      status: 'success',
      message: `Installed ${def.name} at commit ${def.commit.substring(0, 8)}`
    };
  } catch (error) {
    return {
      plugin: def,
      status: 'failed',
      message: `Failed to install ${def.name}`,
      error: error as Error
    };
  }
}
