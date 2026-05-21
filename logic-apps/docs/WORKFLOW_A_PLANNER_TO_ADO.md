# Workflow A — Planner → Azure DevOps

Polls Microsoft Planner every 5 minutes for new tasks and creates corresponding Azure DevOps work items, with a bi-directional link written back to the Planner task.

Definition: [`workflows/flow-a-planner-to-ado/workflow.json`](../workflows/flow-a-planner-to-ado/workflow.json)

---

## Trigger

```
Recurrence — every 5 minutes
```

---

## Execution path

```
1. Recurrence fires
2. HTTP GET Graph: /v1.0/planner/plans/<planId>/tasks
       ?$filter=createdDateTime gt <now - 10 minutes>
       (10-minute lookback gives 2x overlap to absorb skew/missed runs;
        dedup at step 4 prevents duplicates)
   Auth: ManagedServiceIdentity, audience https://graph.microsoft.com

3. For each task:
   a. HTTP GET Graph: /v1.0/planner/tasks/<taskId>/details   → fetch description
   b. If description already contains "ADO_WORK_ITEM_ID:" → skip (already synced)
   c. HTTP POST ADO: /<org>/<project>/_apis/wit/workitems/$<type>?api-version=7.1
         Body: JSON Patch array with System.Title and System.Description
                (description includes "PLANNER_TASK_ID: <taskId>" marker)
      Auth: ManagedServiceIdentity, audience 499b84ac-1321-427f-aa17-267ca6975798
   d. HTTP PATCH Graph: /v1.0/planner/tasks/<taskId>/details
         Body: { "description": "<original>\n\n---\nADO_WORK_ITEM_ID: <id>\nADO_WORK_ITEM_URL: <url>" }
         Header: If-Match: <etag from step 3a>
```

---

## Settings consumed (from Logic App `appsettings`)

| Setting | Source | Example |
|---|---|---|
| `MANAGED_IDENTITY_CLIENT_ID` | Bicep | `<guid>` |
| `PLANNER_GROUP_ID` | Bicep param | `00000000-1111-2222-3333-444444444444` |
| `PLANNER_PLAN_ID` | Bicep param | `AAAAAAAAAAAAAAAAAAAAAAA` |
| `ADO_ORG` | Bicep param | `contoso` |
| `ADO_PROJECT` | Bicep param | `ProductBacklog` |
| `ADO_WORK_ITEM_TYPE` | Bicep param | `Task` |

---

## Key expressions

Inside the workflow JSON you will see the following:

| Purpose | Expression |
|---|---|
| Watermark — 10 minutes ago in ISO 8601 | `@{formatDateTime(addMinutes(utcNow(), -10), 'yyyy-MM-ddTHH:mm:ssZ')}` |
| Filter to skip already-synced tasks | `@{not(contains(coalesce(body('Get_task_details')?['description'], ''), 'ADO_WORK_ITEM_ID:'))}` |
| ADO work item URL (for link-back) | `https://dev.azure.com/@{appsetting('ADO_ORG')}/@{appsetting('ADO_PROJECT')}/_workitems/edit/@{body('Create_work_item')?['id']}` |
| If-Match etag for Planner update | `@{body('Get_task_details')?['@odata.etag']}` |

---

## Idempotency

Each Planner task is identified by its `id`. Before creating a work item, the workflow fetches the task's description and checks for an existing `ADO_WORK_ITEM_ID:` marker. If present, the task is skipped — preventing duplicates if the recurrence overlaps a previous run.

---

## Failure modes & recovery

| Failure | Behaviour | Recovery |
|---|---|---|
| Graph token acquisition fails | Run fails at the first Graph call | Verify Phase 2 of [Deployment](DEPLOYMENT.md) — Graph app roles granted |
| ADO token acquisition fails | Run fails at the ADO POST | Verify the MI is added to the ADO org ([Managed Identity Setup → Step 3](MANAGED_IDENTITY_SETUP.md#step-3--add-the-managed-identity-to-azure-devops)) |
| ADO `403 Forbidden` | MI is in the org but lacks project Contributor role | Add to **Contributors** group on the project |
| Planner PATCH fails with `412 Precondition Failed` | Etag changed between GET and PATCH (concurrent edit) | Next run will retry; non-fatal |

---

## Related Documentation

- Sibling: [Workflow B — ADO to Planner](WORKFLOW_B_ADO_TO_PLANNER.md)
- Architecture: [Architecture Overview](ARCHITECTURE.md)
- Auth setup: [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md)
- Validate: [Testing](TESTING.md) · Issues: [Troubleshooting](TROUBLESHOOTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
