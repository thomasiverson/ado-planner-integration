# Logic Apps Consumption — Planner ↔ Azure DevOps Integration

An alternate, simplified demo track using **Azure Logic Apps Consumption** instead of Logic Apps Standard.

> **This is not the recommended customer install.** It exists because the Standard track (in `../logic-apps/`) requires storage shared-key access, which some Azure subscriptions disable via policy. Consumption uses a fully managed runtime with no customer-owned storage, so it works under the most restrictive policies.
>
> For new customer deployments, prefer the Standard track. Use this track only when policy makes Standard impossible (and a policy exemption or App Service Environment v3 are not options).

## What it deploys

| Resource | Purpose |
|---|---|
| User-assigned managed identity | Authenticates to Microsoft Graph (Planner) and Azure DevOps |
| `Microsoft.Logic/workflows` × 2 | Flow A (Planner → ADO) and Flow B (ADO → Planner) Consumption workflows |

No storage account, no app service plan, no VNet, no private endpoints. Three resources total.

## Workflow logic

Identical behavior to the Standard track — see `../logic-apps/docs/WORKFLOW_A_PLANNER_TO_ADO.md` and `../logic-apps/docs/WORKFLOW_B_ADO_TO_PLANNER.md` for the design.

## Deployment

Mirrors the Standard track but is shorter (no workflow zip-deploy step — the definitions are inlined in the Bicep).

```powershell
# Phase 0 — clone & edit infra/main.bicepparam
cd logic-apps-consumption
# (edit infra/main.bicepparam with your values)

# Phase 1 — provision
az group create -n rg-planla-consumption -l centralus
./scripts/01-deploy.ps1 -ResourceGroupName rg-planla-consumption

# Phase 2 — grant Graph permissions to the MI (one-time, needs Global Admin)
./scripts/02-grant-graph-permissions.ps1 -ManagedIdentityObjectId <from-phase-1-output>

# Phase 3 — add the MI to your ADO org as Contributor (manual; see ../logic-apps/docs/MANAGED_IDENTITY_SETUP.md Step 3)

# Phase 4 — register ADO service hook for Flow B
./scripts/03-configure-ado-service-hook.ps1 -AdoOrg <org> -AdoProject <project> -CallbackUrl <flow-b-url-from-phase-1>
```
