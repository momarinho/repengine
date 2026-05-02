import type { PageServerLoad } from "./$types";
import type { NodeType, PaginatedVersions, Workflow } from "$lib/editor/types";
import { apiFetch, safeJson } from "$lib/server/api";
import {
  normalizeNodeTypes,
  normalizeVersions,
  normalizeWorkflow,
} from "$lib/editor/normalize";

type LoadResult = {
  workflow: Workflow | null;
  nodeTypes: NodeType[];
  versions: PaginatedVersions["data"];
  error: string | null;
};

export const load = (async ({ cookies, fetch, params }) => {
  const token = cookies.get("token");

  const [workflowResponse, nodeTypesResponse, versionsResponse] =
    await Promise.all([
      apiFetch(fetch, `/workflows/${params.id}`, token, { method: "GET" }),
      apiFetch(fetch, "/node-types", token, { method: "GET" }),
      apiFetch(fetch, `/workflows/${params.id}/versions`, token, {
        method: "GET",
      }),
    ]);

  if (!workflowResponse.ok) {
    const errorStatus = workflowResponse.status;
    const errorMessage =
      errorStatus === 404
        ? "Routine not found."
        : errorStatus === 401
          ? "Your session expired."
          : "Failed to load routine.";

    return {
      workflow: null,
      nodeTypes: [],
      versions: [],
      error: errorMessage,
    } satisfies LoadResult;
  }

  const workflow = normalizeWorkflow(
    await safeJson<Workflow>(workflowResponse),
  );
  const nodeTypes = normalizeNodeTypes(
    await safeJson<NodeType[]>(nodeTypesResponse),
  );
  const versions = normalizeVersions(
    await safeJson<PaginatedVersions>(versionsResponse),
  );

  return {
    workflow,
    nodeTypes,
    versions,
    error: workflow ? null : "Routine payload is invalid.",
  } satisfies LoadResult;
}) satisfies PageServerLoad;
