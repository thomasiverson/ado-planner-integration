# Architecture — Logic Apps Edition

## Audience

Solution architects and engineers evaluating or extending the Logic Apps version of the Planner ↔ Azure DevOps integration.

---

## Design Goals

1. **Passwordless** — no PATs, no client secrets, no shared service-account passwords.
2. **IaC-deployable** — `git clone` → edit parameters → `az deployment group create` → working integration.
3. **Engineering-owned** — fits Azure RBAC, Azure Monitor, and existing CI/CD pipelines.
4. **Behaviour parity with Power Automate version** — Flow A (Planner → ADO) and Flow B (ADO → Planner) produce the same outcomes.

---

## Component Overview

| Component | Purpose | API version |
|---|---|---|
| `Microsoft.Web/serverfarms` (Workflow Standard SKU `WS1`) | Compute plan for the Logic App | `2023-12-01` |
| `Microsoft.Web/sites` (kind `functionapp,workflowapp`) | The Logic App Standard host | `2023-12-01` |
| `Microsoft.Storage/storageAccounts` (SKU `Standard_LRS`) | Required runtime backing store | `2023-05-01` |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | Single identity used by both workflows | `2023-01-31` |
| `Microsoft.Authorization/roleAssignments` | Grants the MI Storage Blob Data Owner on its backing storage | `2022-04-01` |

The two workflows (`flow-a-planner-to-ado` and `flow-b-ado-to-planner`) live in the Logic App's file system, deployed via zip deploy.

---

## Identity & Authorization Model

The user-assigned managed identity (`uami-plannerado-<suffix>`) is granted three sets of permissions:

| Target | Permission | Granted via |
|---|---|---|
| Azure Storage (own backing) | `Storage Blob Data Owner`, `Storage Queue Data Contributor`, `Storage Table Data Contributor` | Bicep (`infra/modules/storage.bicep`) |
| Microsoft Graph | App role: `Tasks.ReadWrite.All`, `Group.Read.All` | [`scripts/02-grant-graph-permissions.ps1`](../scripts/02-grant-graph-permissions.ps1) |
| Azure DevOps organization | "User" in the org with **Contributor** at the project scope | [`docs/MANAGED_IDENTITY_SETUP.md`](MANAGED_IDENTITY_SETUP.md) |

Workflows authenticate using the **`ManagedServiceIdentity`** authentication type on every HTTP action, with the appropriate audience:

- Graph: `https://graph.microsoft.com`
- Azure DevOps: `499b84ac-1321-427f-aa17-267ca6975798` (well-known ADO resource ID)

---

## Workflow Triggers

| Workflow | Trigger | Why this choice |
|---|---|---|
| **Flow A — Planner → ADO** | Recurrence (every 5 min) + Graph query for recent tasks | Planner does not have a first-party Logic Apps trigger. Graph webhook subscriptions require an HTTPS-validation handshake and renewal scheduling — polling avoids that complexity for a 5-min SLA. |
| **Flow B — ADO → Planner** | HTTP request trigger, called by an **ADO service hook** | ADO has built-in service hook support for "Work item updated → state changed". Push-based, instant, no polling cost. |

---

## State & Idempotency

Neither workflow keeps explicit state. Idempotency is achieved by **markers in description fields**:

- Flow A writes `PLANNER_TASK_ID: <id>` into the ADO work item's description. Before creating a work item, it scans recent items for an existing marker and skips if found.
- Flow B reads the `ADO_WORK_ITEM_ID` marker from the Planner task description (written by Flow A) to locate the correct Planner task to complete.

This is the same approach used by the Power Automate version — see the parent [SOLUTION_OVERVIEW.md](../../power-automate/docs/SOLUTION_OVERVIEW.md).

---

## Differences from the Power Automate Version

| Concern | Power Automate | Logic Apps |
|---|---|---|
| Trigger for Flow A | Built-in Planner "When a task is created" connector | Recurrence + Graph REST query |
| Trigger for Flow B | Built-in ADO "When a work item is closed" connector | HTTP trigger + ADO service hook |
| Auth | Per-connection OAuth as a user | Managed identity (no user, no secret) |
| Connector → API translation | Hidden by connector | Direct HTTP calls to Graph and ADO REST APIs |
| Environment variables | Power Platform env vars (cleared at export) | Bicep parameters + Logic App `appsettings` |
| Where flow logic lives | Solution `.zip` | `workflows/*/workflow.json` (committed) |
| Failure visibility | Power Automate run history | Application Insights + Logic App run history blade |

---

## Related Documentation

- Set up Azure / M365 / ADO: [Prerequisites](PREREQUISITES.md)
- Deploy: [Deployment Guide](DEPLOYMENT.md)
- Grant identity permissions: [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md)
- Workflow internals: [Workflow A](WORKFLOW_A_PLANNER_TO_ADO.md) · [Workflow B](WORKFLOW_B_ADO_TO_PLANNER.md)
- Validate: [Testing](TESTING.md) · Issues: [Troubleshooting](TROUBLESHOOTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
