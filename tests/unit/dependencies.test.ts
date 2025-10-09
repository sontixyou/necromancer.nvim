import { describe, it, expect } from 'vitest';
import { resolveDependencies, validateDependencies } from '../../src/core/dependencies.js';
import type { PluginDefinition } from '../../src/models/plugin.js';
import { ValidationError } from '../../src/utils/errors.js';

describe('Dependency Resolution', () => {
  describe('resolveDependencies', () => {
    it('should return plugins in correct order when no dependencies exist', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890'
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890'
        }
      ];

      const result = resolveDependencies(plugins);
      expect(result).toHaveLength(2);
      expect(result.map(p => p.name)).toEqual(['plugin-a', 'plugin-b']);
    });

    it('should resolve simple dependency chain correctly', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-b']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890'
        }
      ];

      const result = resolveDependencies(plugins);
      expect(result).toHaveLength(2);
      expect(result.map(p => p.name)).toEqual(['plugin-b', 'plugin-a']);
    });

    it('should resolve complex dependency tree correctly', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-b', 'plugin-c']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-d']
        },
        {
          name: 'plugin-c',
          repo: 'https://github.com/user/plugin-c',
          commit: '1234567890123456789012345678901234567890'
        },
        {
          name: 'plugin-d',
          repo: 'https://github.com/user/plugin-d',
          commit: '1234567890123456789012345678901234567890'
        }
      ];

      const result = resolveDependencies(plugins);
      expect(result).toHaveLength(4);
      
      const names = result.map(p => p.name);
      
      // Verify plugin-d comes before plugin-b
      expect(names.indexOf('plugin-d')).toBeLessThan(names.indexOf('plugin-b'));
      
      // Verify plugin-b and plugin-c come before plugin-a
      expect(names.indexOf('plugin-b')).toBeLessThan(names.indexOf('plugin-a'));
      expect(names.indexOf('plugin-c')).toBeLessThan(names.indexOf('plugin-a'));
    });

    it('should handle empty dependencies array', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: []
        }
      ];

      const result = resolveDependencies(plugins);
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('plugin-a');
    });

    it('should throw error for missing dependency', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['non-existent-plugin']
        }
      ];

      expect(() => resolveDependencies(plugins)).toThrow(ValidationError);
      expect(() => resolveDependencies(plugins)).toThrow('depends on "non-existent-plugin"');
    });

    it('should detect circular dependencies (simple cycle)', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-b']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-a']
        }
      ];

      expect(() => resolveDependencies(plugins)).toThrow(ValidationError);
      expect(() => resolveDependencies(plugins)).toThrow('Circular dependency detected');
    });

    it('should detect circular dependencies (complex cycle)', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-b']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-c']
        },
        {
          name: 'plugin-c',
          repo: 'https://github.com/user/plugin-c',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-a']
        }
      ];

      expect(() => resolveDependencies(plugins)).toThrow(ValidationError);
      expect(() => resolveDependencies(plugins)).toThrow('Circular dependency detected');
    });

    it('should handle self-dependency as circular dependency', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-a']
        }
      ];

      expect(() => resolveDependencies(plugins)).toThrow(ValidationError);
      expect(() => resolveDependencies(plugins)).toThrow('Circular dependency detected');
    });

    it('should maintain stable order for plugins at same dependency level', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-d']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-d']
        },
        {
          name: 'plugin-c',
          repo: 'https://github.com/user/plugin-c',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-d']
        },
        {
          name: 'plugin-d',
          repo: 'https://github.com/user/plugin-d',
          commit: '1234567890123456789012345678901234567890'
        }
      ];

      const result = resolveDependencies(plugins);
      const names = result.map(p => p.name);
      
      // plugin-d should come first
      expect(names[0]).toBe('plugin-d');
      
      // The other plugins should maintain some order but come after plugin-d
      expect(names.indexOf('plugin-a')).toBeGreaterThan(0);
      expect(names.indexOf('plugin-b')).toBeGreaterThan(0);
      expect(names.indexOf('plugin-c')).toBeGreaterThan(0);
    });
  });

  describe('validateDependencies', () => {
    it('should not throw for valid dependency configuration', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-b']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890'
        }
      ];

      expect(() => validateDependencies(plugins)).not.toThrow();
    });

    it('should throw for invalid dependency configuration', () => {
      const plugins: PluginDefinition[] = [
        {
          name: 'plugin-a',
          repo: 'https://github.com/user/plugin-a',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-b']
        },
        {
          name: 'plugin-b',
          repo: 'https://github.com/user/plugin-b',
          commit: '1234567890123456789012345678901234567890',
          dependencies: ['plugin-a']
        }
      ];

      expect(() => validateDependencies(plugins)).toThrow(ValidationError);
    });
  });
});