#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { install } from './commands/install.js';
import { update } from './commands/update.js';
import { list } from './commands/list.js';
import { verify } from './commands/verify.js';
import { clean } from './commands/clean.js';
import { init } from './commands/init.js';

const HELP_TEXT = `
Necromancer - Neovim plugin manager with commit-based versioning

Usage:
  necromancer <command> [options]

Commands:
  init              Create a new configuration file
  install           Install plugins from config file
  update [plugins]  Update plugins to latest config commits
  list              List installed plugins and their status
  verify            Verify plugin installations
  clean             Remove plugins not in config
  help              Show this help message

Options:
  --config <path>   Path to config file (default: .necromancer.json)
  --verbose         Enable verbose output
  --fix             Auto-repair corrupted installations (verify only)
  --dry-run         Show what would be removed (clean only)
  --force           Skip confirmation prompts
  --auto-clean      Remove orphaned plugins after install

Examples:
  necromancer init
  necromancer install
  necromancer install --verbose
  necromancer update
  necromancer list
  necromancer verify --fix
  necromancer clean --dry-run
  necromancer clean --force
`;

/**
 * Parse command-line arguments
 */
function parseCliArgs(): { command: string; options: Record<string, unknown> } {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === 'help' || args[0] === '--help' || args[0] === '-h') {
    console.log(HELP_TEXT);
    process.exit(0);
  }

  const command = args[0];
  if (!command) {
    console.error('Error: No command specified');
    console.error('Run "necromancer help" for usage information.');
    process.exit(1);
  }

  const validCommands = ['init', 'install', 'update', 'list', 'verify', 'clean'];

  if (!validCommands.includes(command)) {
    console.error(`Error: Unknown command "${command}"`);
    console.error('Run "necromancer help" for usage information.');
    process.exit(1);
  }

  // Parse options
  try {
    const { values, positionals } = parseArgs({
      args: args.slice(1),
      options: {
        config: { type: 'string' },
        verbose: { type: 'boolean' },
        fix: { type: 'boolean' },
        'dry-run': { type: 'boolean' },
        force: { type: 'boolean' },
        'auto-clean': { type: 'boolean' },
      },
      strict: true,
      allowPositionals: true,
    });

    // Convert parsed values to options object
    const options: Record<string, unknown> = {};
    if (values.config) options.config = values.config;
    if (values.verbose) options.verbose = values.verbose;
    if (values.fix) options.fix = values.fix;
    if (values['dry-run']) options.dryRun = values['dry-run'];
    if (values.force) options.force = values.force;
    if (values['auto-clean']) options.autoClean = values['auto-clean'];

    // For update command, capture plugin names as positional arguments
    if (command === 'update' && positionals.length > 0) {
      options.plugins = positionals;
    }

    return { command, options };
  } catch (error) {
    console.error(`Error: ${(error as Error).message}`);
    console.error('Run "necromancer help" for usage information.');
    process.exit(1);
  }
}

/**
 * Main CLI entry point
 */
async function main(): Promise<void> {
  const { command, options } = parseCliArgs();

  let exitCode: number;

  try {
    switch (command) {
      case 'init':
        exitCode = await init(options);
        break;
      case 'install':
        exitCode = await install(options);
        break;
      case 'update':
        exitCode = await update(options);
        break;
      case 'list':
        exitCode = await list(options);
        break;
      case 'verify':
        exitCode = await verify(options);
        break;
      case 'clean':
        exitCode = await clean(options);
        break;
      default:
        console.error(`Error: Command "${command}" not implemented`);
        exitCode = 1;
    }
  } catch (error) {
    console.error(`Fatal error: ${(error as Error).message}`);
    exitCode = 3;
  }

  process.exit(exitCode);
}

// Run CLI
main().catch(error => {
  console.error(`Fatal error: ${error.message}`);
  process.exit(3);
});
