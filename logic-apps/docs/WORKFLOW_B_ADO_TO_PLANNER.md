# Workflow B — Azure DevOps → Planner

Triggered by an Azure DevOps **service hook** when a work item transitions to a closed state. Marks the linked Planner task complete.

Definition: [`workflows/flow-b-ado-to-planner/workflow.json`](../workflows/flow-b-ado-to-planner/workflow.json)

---

## Trigger

```
HTTP request — POST from Azure DevOps service hook
```

The trigger URL (with SAS) is generated automatically when the workflow is deployed and surfaced by [`scripts/03-deploy-workflows.ps1`](../scripts/03-deploy-workflows.ps1). You hand that URL to [`scripts/04-configure-ado-service-hook.ps1`](../scripts/04-configure-ado-service-hook.ps1).

---

## Execution path

```
1. ADO service hook POSTs work item update payload
   Payload includes: resource.id, resource.fields, resource.revision, resource._links

2. Condition: was the state transitioned to a closed state?
       triggerBody()?['resource']?['fields']?['System.State'] in ['Done', 'Closed', 'Completed', 'Resolved']
   If false → terminate (Succeeded, no-op)

3. HTTP GET ADO: /<org>/<project>/_apis/wit/workitems/<id>?$expand=all&api-version=7.1
   Auth: ManagedServiceIdentity, audience 499b84ac-1321-427f-aa17-267ca6975798
   → fetch the work item's full description

4. Extract Planner task ID from description
   Look for: PLANNER_TASK_ID: <guid>
   Use a Compose with split() / substring() to extract the GUID
   If marker not found → terminate (Succeeded, no-op)

5. HTTP GET Graph: /v1.0/planner/tasks/<plannerTaskId>
   Auth: ManagedServiceIdentity, audience https://graph.microsoft.com
   → fetch current etag

6. HTTP PATCH Graph: /v1.0/planner/tasks/<plannerTaskId>
   Body: { "percentComplete": 100 }
   Headers: If-Match: <etag from step 5>
```

---

## Settings consumed

| Setting | Used for |
|---|---|
| `MANAGED_IDENTITY_CLIENT_ID` | Identifies which UAMI to use for token acquisition |
| `ADO_ORG`, `ADO_PROJECT` | URL construction for step 3 |

---

## Key expressions

| Purpose | Expression |
|---|---|
| State check | `@or(equals(triggerBody()?['resource']?['fields']?['System.State'], 'Done'), equals(triggerBody()?['resource']?['fields']?['System.State'], 'Closed'))` |
| Extract Planner task ID from ADO description | `@{trim(first(split(last(split(coalesce(body('Get_work_item')?['fields']?['System.Description'], ''), 'PLANNER_TASK_ID:')), ' ')))}` |
| Etag for Planner PATCH | `@{body('Get_planner_task')?['@odata.etag']}` |

> **Why the extraction expression is gnarly:** ADO returns description as HTML. The marker may be followed by `</p>`, `<br/>`, or whitespace. Splitting on `PLANNER_TASK_ID:` then on the first space, trimmed, reliably yields the GUID across the variations we see in practice.

---

## Idempotency

Calling `PATCH /tasks/<id>` with `{ "percentComplete": 100 }` on an already-complete task is a no-op (returns `204`). Safe to receive duplicate service hook posts.

---

## Failure modes & recovery

| Failure | Behaviour | Recovery |
|---|---|---|
| State condition false | Workflow returns 200 immediately | Expected for in-progress updates |
| `PLANNER_TASK_ID` marker absent | Workflow returns 200, terminate Succeeded | Expected for work items not created by Flow A |
| Graph PATCH returns `412 Precondition Failed` | Etag stale | Logic Apps retry policy retries (default 4 retries) |
| Graph PATCH returns `403 Forbidden` | App role not granted | Re-run [Phase 2](DEPLOYMENT.md#phase-2--grant-microsoft-graph-permissions) |
| ADO GET returns `401 Unauthorized` | MI not added to ADO org or token audience wrong | Verify [Managed Identity Setup → Step 3](MANAGED_IDENTITY_SETUP.md#step-3--add-the-managed-identity-to-azure-devops) |

---

## Why a service hook, not a poller?

The Power Automate version uses a built-in "When a work item is closed" trigger that internally polls every 1–3 minutes. The Logic Apps version uses **ADO service hooks** for:

- **Lower latency** — sub-second vs. 1–3 minutes
- **Lower cost** — no recurrence executions when nothing is happening
- **Cleaner observability** — every invocation corresponds to a real ADO event

Trade-off: registering the service hook is an extra deployment step (Phase 5 in [Deployment Guide](DEPLOYMENT.md)).

---

## Related Documentation

- Sibling: [Workflow A — Planner to ADO](WORKFLOW_A_PLANNER_TO_ADO.md)
- Architecture: [Architecture Overview](ARCHITECTURE.md)
- Auth setup: [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md)
- Validate: [Testing](TESTING.md) · Issues: [Troubleshooting](TROUBLESHOOTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
