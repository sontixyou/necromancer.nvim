import type { PluginDefinition } from '../models/plugin.js';
import { ValidationError } from '../utils/errors.js';

/**
 * Resolve plugin dependencies and return plugins in installation order
 * Uses topological sorting to ensure dependencies are installed before dependents
 * @param plugins - Array of plugin definitions
 * @returns Array of plugins sorted by dependency order
 * @throws ValidationError if circular dependencies are detected or dependencies are missing
 */
export function resolveDependencies(plugins: PluginDefinition[]): PluginDefinition[] {
  // Create a map for quick lookup
  const pluginMap = new Map<string, PluginDefinition>();
  for (const plugin of plugins) {
    pluginMap.set(plugin.name, plugin);
  }

  // Validate that all dependencies exist in the plugin list
  for (const plugin of plugins) {
    if (plugin.dependencies) {
      for (const depName of plugin.dependencies) {
        if (!pluginMap.has(depName)) {
          throw new ValidationError(`Plugin "${plugin.name}" depends on "${depName}", but "${depName}" is not defined in the configuration`);
        }
      }
    }
  }

  // Topological sort using Kahn's algorithm
  const inDegree = new Map<string, number>();
  const adjacencyList = new Map<string, string[]>();
  
  // Initialize in-degree count and adjacency list
  for (const plugin of plugins) {
    inDegree.set(plugin.name, 0);
    adjacencyList.set(plugin.name, []);
  }
  
  // Build the dependency graph
  for (const plugin of plugins) {
    if (plugin.dependencies) {
      for (const depName of plugin.dependencies) {
        // depName should be installed before plugin.name
        adjacencyList.get(depName)?.push(plugin.name);
        inDegree.set(plugin.name, (inDegree.get(plugin.name) || 0) + 1);
      }
    }
  }
  
  // Queue for processing (plugins with no dependencies)
  const queue: string[] = [];
  const result: PluginDefinition[] = [];
  
  // Find all plugins with no incoming edges (no dependencies)
  for (const [pluginName, degree] of inDegree) {
    if (degree === 0) {
      queue.push(pluginName);
    }
  }
  
  // Process the queue
  while (queue.length > 0) {
    const current = queue.shift()!;
    const currentPlugin = pluginMap.get(current)!;
    result.push(currentPlugin);
    
    // Remove this node from the graph and update in-degrees
    const neighbors = adjacencyList.get(current) || [];
    for (const neighbor of neighbors) {
      const newDegree = (inDegree.get(neighbor) || 0) - 1;
      inDegree.set(neighbor, newDegree);
      
      if (newDegree === 0) {
        queue.push(neighbor);
      }
    }
  }
  
  // Check for circular dependencies
  if (result.length !== plugins.length) {
    const remainingPlugins = plugins
      .filter(plugin => !result.some(resolved => resolved.name === plugin.name))
      .map(plugin => plugin.name);
    throw new ValidationError(`Circular dependency detected involving plugins: ${remainingPlugins.join(', ')}`);
  }
  
  return result;
}

/**
 * Validate plugin dependencies without sorting
 * @param plugins - Array of plugin definitions
 * @throws ValidationError if dependencies are invalid
 */
export function validateDependencies(plugins: PluginDefinition[]): void {
  // This will throw if there are issues
  resolveDependencies(plugins);
}