import { ValidationError } from '../utils/errors.js';

/**
 * Regex for validating GitHub HTTPS URLs
 * Matches: https://github.com/owner/repo or https://github.com/owner/repo.git
 */
const GITHUB_URL_REGEX = /^https:\/\/github\.com\/[\w-]+\/[\w.-]+(?:\.git)?$/;

/**
 * Regex for validating Git commit hashes (40-character SHA-1)
 */
const COMMIT_HASH_REGEX = /^[a-f0-9]{40}$/i;

/**
 * Regex for validating plugin names
 * Allows: alphanumeric, hyphens, underscores, dots, 1-100 characters
 * Excludes: names starting with hyphen
 */
const PLUGIN_NAME_REGEX = /^[\w][\w.-]{0,99}$/;

/**
 * Regex for detecting shell metacharacters that could be used for injection
 */
const SHELL_METACHAR_REGEX = /[;&|`$()<>\n]/;

/**
 * Validate GitHub repository URL
 * @param url - URL to validate
 * @returns true if valid GitHub HTTPS URL, false otherwise
 */
export function isValidGitHubUrl(url: string): boolean {
  return GITHUB_URL_REGEX.test(url);
}

/**
 * Validate Git commit hash
 * @param hash - Commit hash to validate
 * @returns true if valid 40-character SHA-1 hash, false otherwise
 */
export function isValidCommitHash(hash: string): boolean {
  return COMMIT_HASH_REGEX.test(hash);
}

/**
 * Validate plugin name
 * @param name - Plugin name to validate
 * @returns true if valid plugin name, false otherwise
 */
export function isValidPluginName(name: string): boolean {
  return PLUGIN_NAME_REGEX.test(name);
}

/**
 * Sanitize shell input to prevent command injection
 * @param input - Input string to sanitize
 * @throws ValidationError if input contains shell metacharacters
 */
export function sanitizeShellInput(input: string): void {
  if (SHELL_METACHAR_REGEX.test(input)) {
    throw new ValidationError('Invalid characters in input: shell metacharacters are not allowed');
  }
}
