import type { NodeType, PaginatedVersions, Workflow } from "$lib/editor/types";

export function normalizeWorkflow(workflow: Workflow | null): Workflow | null {
  if (!workflow) return null;

  return {
    ...workflow,
    blocks: Array.isArray(workflow.blocks) ? workflow.blocks : [],
  };
}

export function normalizeNodeTypes(
  nodeTypes: NodeType[] | null | undefined,
): NodeType[] {
  if (!Array.isArray(nodeTypes)) return [];
  return nodeTypes;
}

export function normalizeVersions(
  payload: PaginatedVersions | null | undefined,
) {
  if (!payload || !Array.isArray(payload.data)) return [];
  return payload.data;
}
