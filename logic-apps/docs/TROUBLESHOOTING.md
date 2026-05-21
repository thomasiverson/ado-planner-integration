# Troubleshooting — Logic Apps Edition

---

## Audience

The engineer or operator diagnosing a failing workflow.

---

## Diagnostics quick-start

1. Azure portal → your Logic App (Standard) → **Workflows** → select the affected workflow → **Run history**
2. Click the most recent failed run → expand the failing action → read the **Outputs** pane (HTTP status, body)
3. If the failure is intermittent, enable **Application Insights** on the Logic App (Bicep already provisions it on request — see [`infra/main.bicep`](../infra/main.bicep))

---

## Common issues

### 1. Trigger never fires (Workflow A)

**Symptoms:** No runs in Workflow A's run history.

| Possible cause | Resolution |
|---|---|
| Workflow disabled | Workflows → select → **Enable** |
| Logic App stopped | Overview → **Start** |
| Storage account inaccessible (MI lost permission) | Verify `Storage Blob Data Owner` role assignment on the storage account |
| Time zone misconfiguration on the recurrence | Edit recurrence; explicit `UTC` recommended |

---

### 2. Trigger never fires (Workflow B)

**Symptoms:** Closing an ADO work item produces no Workflow B run.

| Possible cause | Resolution |
|---|---|
| ADO service hook not registered | `https://dev.azure.com/<org>/<project>/_settings/serviceHooks` — confirm one exists pointing at the Logic App URL |
| Service hook URL stale | Re-run [`scripts/04-configure-ado-service-hook.ps1`](../scripts/04-configure-ado-service-hook.ps1) — the trigger URL changes when the workflow is redeployed |
| Service hook filter excludes your state | Check filter — it should match the state(s) your process uses (`Done`, `Closed`, `Completed`, `Resolved`) |
| ADO service hook authentication failed | Service hooks page → click the hook → **History** — look for `401`/`403` |

---

### 3. `401 Unauthorized` calling Microsoft Graph

**Symptoms:** Workflow A or B run fails at a Graph HTTP action with `401`.

| Cause | Resolution |
|---|---|
| App role not granted | Re-run [`scripts/02-grant-graph-permissions.ps1`](../scripts/02-grant-graph-permissions.ps1) |
| `MANAGED_IDENTITY_CLIENT_ID` app setting missing or wrong | Logic App → **Configuration** → verify the value matches the UAMI's Client ID (not Object ID) |
| Workflow HTTP action audience wrong | Must be `https://graph.microsoft.com` (no trailing slash) |
| Token cache stale after permission grant | Wait 5 minutes for Graph to propagate, then resubmit |

---

### 4. `403 Forbidden` calling Microsoft Graph

**Symptoms:** Authenticated but rejected.

| Cause | Resolution |
|---|---|
| Wrong app role for the operation | `Tasks.ReadWrite.All` is required for both read and write — `Tasks.Read.All` alone is insufficient for the PATCH |
| Plan ID belongs to a group the MI cannot resolve | Verify `Group.Read.All` was granted |

---

### 5. `401 Unauthorized` calling Azure DevOps

**Symptoms:** Workflow A's ADO POST or Workflow B's ADO GET fails with `401`.

| Cause | Resolution |
|---|---|
| MI not added to the ADO organization | [Managed Identity Setup → Step 3](MANAGED_IDENTITY_SETUP.md#step-3--add-the-managed-identity-to-azure-devops) |
| ADO org not in the same Entra tenant as the subscription | Verify under `https://dev.azure.com/<org>/_settings/organizationAad` — they must match |
| HTTP action audience wrong | Must be exactly `499b84ac-1321-427f-aa17-267ca6975798` |

---

### 6. `403 Forbidden` calling Azure DevOps

| Cause | Resolution |
|---|---|
| MI lacks **Contributor** at project scope | Add to `Contributors` group on the project |
| Process template doesn't permit creating the work item type as Contributor | Use a higher-privileged group (e.g., `Project Administrators`) or change `ADO_WORK_ITEM_TYPE` |

---

### 7. Workflow A creates duplicate work items

**Symptoms:** Multiple ADO items for the same Planner task.

| Cause | Resolution |
|---|---|
| Description marker not being checked | Verify the workflow JSON includes the **Condition: skip if `ADO_WORK_ITEM_ID:` already in description** step |
| Custom Planner client strips description on first save | The marker write-back may be racing; raise the recurrence interval to 10 min, or implement a tag-based dedup in addition to the marker |

---

### 8. Workflow B doesn't complete the Planner task

| Cause | Resolution |
|---|---|
| `PLANNER_TASK_ID:` marker malformed in ADO description | Open the ADO item → confirm the marker is present and a clean GUID follows it. ADO stores HTML — check the raw HTML, not the rendered view |
| Etag handling — `412 Precondition Failed` from Graph | Logic Apps default retry policy handles this (up to 4 retries). If still failing, manual edit on the Planner task changed the etag; close again |
| Wrong Planner Plan / Group ID in `appsettings` | Logic App → **Configuration** → confirm `PLANNER_GROUP_ID` and `PLANNER_PLAN_ID` |

---

### 9. Bicep deployment fails on role assignment

**Symptoms:** `01-deploy-infra.ps1` errors with `AuthorizationFailed` on a role assignment resource.

| Cause | Resolution |
|---|---|
| Deployer lacks `Owner` or `User Access Administrator` on the RG | Grant the role temporarily or delegate the role assignment to an admin |
| Deployer principal is a Service Principal without `RoleBasedAccessControl.Administrator` in Entra | Use a user principal for initial deployment, or add the SP to the Entra role |

---

### 10. Workflow zip deploy fails

**Symptoms:** `03-deploy-workflows.ps1` errors with `403` or `500`.

| Cause | Resolution |
|---|---|
| Logic App stopped during deploy | Start it, then retry |
| Run-from-package conflict | Logic App → **Configuration** → confirm `WEBSITE_RUN_FROM_PACKAGE` is `1` (zip deploy mode) |
| Cold start timing out | Re-run the script; subsequent deploys are faster |

---

## Escalation path

1. Capture the **run ID** from the run history URL.
2. Export the run JSON: portal → run → **... → Download run**.
3. Collect Logic App `appsettings` (redact secrets — though we don't have any).
4. Application Insights → **Failures** blade → filter by `cloud_RoleName = <logic-app-name>`.
5. Open a support ticket against **Logic Apps Standard** with the above artifacts.

---

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md)
- [Workflow A](WORKFLOW_A_PLANNER_TO_ADO.md) · [Workflow B](WORKFLOW_B_ADO_TO_PLANNER.md)
- [Testing](TESTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
