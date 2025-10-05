import { execSync } from 'child_process';
import { GitError } from '../utils/errors.js';

/**
 * Build git clone command with proper quoting and flags
 * Removes shell command separators as defense-in-depth
 * IMPORTANT: Input validation SHOULD occur before calling this function
 * @param url - Repository URL to clone
 * @param targetPath - Destination path for clone
 * @returns Git clone command string
 */
export function buildGitCloneCommand(url: string, targetPath: string): string {
  // Remove semicolons as basic injection prevention (defense-in-depth)
  const safeUrl = url.replace(/;/g, '');
  const safePath = targetPath.replace(/;/g, '');
  return `git clone --quiet "${safeUrl}" "${safePath}"`;
}

/**
 * Build git checkout command with proper quoting and flags
 * Removes shell command separators as defense-in-depth
 * @param commit - Commit hash to checkout
 * @returns Git checkout command string
 */
export function buildGitCheckoutCommand(commit: string): string {
  // Remove semicolons as basic injection prevention
  const safeCommit = commit.replace(/;/g, '');
  return `git checkout --quiet "${safeCommit}"`;
}

/**
 * Build git fetch command with proper flags
 * @returns Git fetch command string
 */
export function buildGitFetchCommand(): string {
  return 'git fetch --quiet --all';
}

/**
 * Clone a git repository
 * @param url - Repository URL to clone
 * @param targetPath - Destination path for clone
 * @throws GitError if clone fails
 */
export function gitClone(url: string, targetPath: string): void {
  try {
    const command = buildGitCloneCommand(url, targetPath);
    execSync(command, {
      encoding: 'utf-8',
      stdio: 'pipe',
      windowsHide: true
    });
  } catch (error) {
    const err = error as Error & { stderr?: string };
    const errorMessage = err.stderr || err.message;
    throw new GitError(`Failed to clone ${url}: ${errorMessage}`);
  }
}

/**
 * Checkout a specific commit in a git repository
 * @param repoPath - Path to the git repository
 * @param commit - Commit hash to checkout
 * @throws GitError if checkout fails
 */
export function gitCheckout(repoPath: string, commit: string): void {
  try {
    const command = buildGitCheckoutCommand(commit);
    execSync(command, {
      cwd: repoPath,
      encoding: 'utf-8',
      stdio: 'pipe',
      windowsHide: true
    });
  } catch (error) {
    const err = error as Error & { stderr?: string };
    const errorMessage = err.stderr || err.message;
    throw new GitError(`Failed to checkout commit ${commit}: ${errorMessage}`);
  }
}

/**
 * Fetch updates from remote repository
 * @param repoPath - Path to the git repository
 * @throws GitError if fetch fails
 */
export function gitFetch(repoPath: string): void {
  try {
    const command = buildGitFetchCommand();
    execSync(command, {
      cwd: repoPath,
      encoding: 'utf-8',
      stdio: 'pipe',
      windowsHide: true
    });
  } catch (error) {
    const err = error as Error & { stderr?: string };
    const errorMessage = err.stderr || err.message;
    throw new GitError(`Failed to fetch updates: ${errorMessage}`);
  }
}

/**
 * Get the current commit hash of a git repository
 * @param repoPath - Path to the git repository
 * @returns Current commit hash (40 characters)
 * @throws GitError if unable to get current commit
 */
export function getCurrentCommit(repoPath: string): string {
  try {
    const output = execSync('git rev-parse HEAD', {
      cwd: repoPath,
      encoding: 'utf-8',
      stdio: 'pipe',
      windowsHide: true
    });
    return output.trim();
  } catch (error) {
    const err = error as Error & { stderr?: string };
    const errorMessage = err.stderr || err.message;
    throw new GitError(`Failed to get current commit: ${errorMessage}`);
  }
}
