# Deployment Guide — Logic Apps Edition

End-to-end walkthrough to deploy the integration. Estimated effort: 30–60 minutes the first time.

---

## Audience

The engineer running the deployment. Assumes [Prerequisites](PREREQUISITES.md) are complete.

---

## Overview

The deployment proceeds in four phases via four scripts:

| # | Phase | Script | What it does |
|---|---|---|---|
| 1 | Provision Azure infra | [`01-deploy-infra.ps1`](../scripts/01-deploy-infra.ps1) | Deploys Bicep: storage, plan, Logic App, UAMI, role assignments |
| 2 | Grant Graph permissions | [`02-grant-graph-permissions.ps1`](../scripts/02-grant-graph-permissions.ps1) | Assigns `Tasks.ReadWrite.All` + `Group.Read.All` app roles to the UAMI |
| 3 | Deploy workflows | [`03-deploy-workflows.ps1`](../scripts/03-deploy-workflows.ps1) | Zip-deploys the `workflows/` folder into the Logic App |
| 4 | Register ADO service hook | [`04-configure-ado-service-hook.ps1`](../scripts/04-configure-ado-service-hook.ps1) | Creates the ADO service hook that triggers Flow B |

You must also manually add the managed identity to the ADO organization (see [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md)).

---

## Phase 0 — Clone & configure parameters

```powershell
git clone <repo-url> ado-planner-integration
cd ado-planner-integration/logic-apps
```

Open [`infra/main.bicepparam`](../infra/main.bicepparam) and set the values for your deployment:

```bicep
param namePrefix = 'plannerado'        // 3–11 chars, lowercase, used to derive resource names
param location = 'eastus'              // any Logic Apps Standard region
param adoOrg = 'contoso'
param adoProject = 'ProductBacklog'
param adoWorkItemType = 'Task'
param plannerGroupId = '00000000-1111-2222-3333-444444444444'
param plannerPlanId = 'AAAAAAAAAAAAAAAAAAAAAAA'
```

These values are written into the Logic App's `appsettings` so the workflows can read them as `@appsetting('ADO_ORG')`, etc.

---

## Phase 1 — Deploy Azure infrastructure

```powershell
# Sign in to Azure (one-time per session)
az login
az account set --subscription "<your-subscription-id-or-name>"

# Create the target resource group (or use an existing one)
az group create --name rg-plannerado --location eastus

# Deploy
./scripts/01-deploy-infra.ps1 -ResourceGroupName rg-plannerado
```

The script wraps:

```powershell
az deployment group create `
  --resource-group rg-plannerado `
  --template-file ./infra/main.bicep `
  --parameters ./infra/main.bicepparam
```

When it completes, it prints the **outputs** you need for the next phases:

```
logicAppName        : la-plannerado-xxxxx
logicAppHostname    : la-plannerado-xxxxx.azurewebsites.net
managedIdentityName : uami-plannerado-xxxxx
managedIdentityId   : <objectId>
storageAccountName  : stplanneradoxxxxx
```

Save the `managedIdentityId` (the **object/principal ID** of the user-assigned identity) — Phase 2 needs it.

---

## Phase 2 — Grant Microsoft Graph permissions

The managed identity must be granted application permissions on Microsoft Graph so the workflows can read Planner tasks and update them.

```powershell
./scripts/02-grant-graph-permissions.ps1 -ManagedIdentityObjectId <managedIdentityId-from-Phase-1>
```

What it grants:

| Graph app role | Used by |
|---|---|
| `Tasks.ReadWrite.All` | Flow A (read new tasks) and Flow B (mark tasks complete) |
| `Group.Read.All` | Resolving the Planner plan via its owning group |

> Requires **Global Administrator** or **Privileged Role Administrator** at the time of consent. The grant is one-time and persists for the life of the managed identity.

---

## Phase 3 — Add the managed identity to Azure DevOps

This step is **manual** — Azure DevOps does not have a public REST API for user invitations that works cleanly with managed identities. See the full walkthrough: [Managed Identity Setup → Step 3](MANAGED_IDENTITY_SETUP.md#step-3--add-the-managed-identity-to-azure-devops).

Summary:

1. Open `https://dev.azure.com/<your-org>/_settings/users`.
2. **Add users** → enter the managed identity's display name (e.g., `uami-plannerado-xxxxx`) → search → select.
3. Set **Access level** = **Basic** and **Add to projects** = your target project as **Contributor**.

> The managed identity must be in the same Entra tenant as the ADO organization. See [Prerequisites](PREREQUISITES.md#azure-devops).

---

## Phase 4 — Deploy workflow definitions

```powershell
./scripts/03-deploy-workflows.ps1 -ResourceGroupName rg-plannerado -LogicAppName <logicAppName-from-Phase-1>
```

What it does:

1. Packages the `workflows/` folder (host.json + connections.json + both workflow.json files) into a `workflows.zip`.
2. Uses `az logicapp deployment source config-zip` to push it to the Logic App.
3. Waits for the deployment to complete and prints the **HTTP trigger URL** of Flow B (you need this for Phase 5).

---

## Phase 5 — Register the ADO service hook for Flow B

```powershell
./scripts/04-configure-ado-service-hook.ps1 `
  -AdoOrg contoso `
  -AdoProject ProductBacklog `
  -CallbackUrl '<Flow-B-trigger-URL-from-Phase-4>'
```

What it registers in ADO:

| Setting | Value |
|---|---|
| Event | `workitem.updated` |
| Filter | `System.WorkItemType = <ADO_WORK_ITEM_TYPE>` and state transitioned to `Done` or `Closed` |
| Action | `webHooks` HTTP POST to the Logic App trigger URL |

Verify the hook in `https://dev.azure.com/<org>/<project>/_settings/serviceHooks`.

---

## Phase 6 — Smoke test

Follow the [Testing](TESTING.md) plan.

---

## Tearing it all down

```powershell
# Remove ADO service hook (UI: Project settings → Service hooks → delete)

# Remove Azure resources
az group delete --name rg-plannerado --yes --no-wait

# Remove Graph app role assignments (optional — clean up the orphaned MI principal afterwards)
# See scripts/02-grant-graph-permissions.ps1 -Revoke for an automated path
```

---

## Related Documentation

- Prerequisites: [Prerequisites](PREREQUISITES.md)
- Identity details: [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md)
- Workflow internals: [Workflow A](WORKFLOW_A_PLANNER_TO_ADO.md) · [Workflow B](WORKFLOW_B_ADO_TO_PLANNER.md)
- Validate: [Testing](TESTING.md)
- Issues: [Troubleshooting](TROUBLESHOOTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
