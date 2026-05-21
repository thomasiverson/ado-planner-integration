# Prerequisites — Logic Apps Edition

## Audience

The engineer deploying the integration for the first time.

---

## Azure

| Requirement | Details |
|---|---|
| Azure subscription | Active subscription with quota for App Service plan (WS1) and Storage |
| Resource group | One target resource group (the deployment is RG-scoped) |
| RBAC | **Owner** or **User Access Administrator** on the resource group (needed for role assignments inside the Bicep template) |
| Region | Any region that supports Logic Apps Standard (e.g., `eastus`, `westus2`, `westeurope`) |

---

## Local tooling

Install the following on the workstation that will run the deployment:

| Tool | Version | Verify |
|---|---|---|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | `2.60.0` or later | `az --version` |
| [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) | `0.27.0` or later | `az bicep version` |
| [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/powershell/microsoftgraph/installation) | `2.x` | `Get-Module Microsoft.Graph -ListAvailable` |
| PowerShell | `7.4+` (Windows, macOS, Linux) | `pwsh --version` |
| Git | any | `git --version` |

Install commands:

```powershell
# Azure CLI — see https://learn.microsoft.com/cli/azure/install-azure-cli
winget install -e --id Microsoft.AzureCLI

# Bicep (bundled with Azure CLI; ensure latest)
az bicep upgrade

# Microsoft Graph PowerShell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

---

## Microsoft 365 / Planner

| Requirement | Details |
|---|---|
| Microsoft 365 tenant | Tenant that hosts the Planner plan |
| Planner plan | A plan inside a Microsoft 365 Group |
| Permissions to grant Graph app roles | **Global Administrator** or **Privileged Role Administrator** — required *once* to consent to the application permissions for the managed identity (`Tasks.ReadWrite.All`, `Group.Read.All`) |

You will need these values during deployment:

| Value | How to find |
|---|---|
| `PLANNER_GROUP_ID` (Microsoft 365 Group Object ID) | [Entra admin center](https://entra.microsoft.com) → Groups → your group → Overview → Object ID |
| `PLANNER_PLAN_ID` | Open the plan in Planner; the URL contains `/plans/<planId>/...` |
| `M365_TENANT_ID` | [Entra admin center](https://entra.microsoft.com) → Overview → Tenant ID |

---

## Azure DevOps

| Requirement | Details |
|---|---|
| ADO organization | Connected to the same Entra tenant as the Logic App's managed identity |
| Project | Target project for the synced work items |
| Permissions | **Project Collection Administrator** (or equivalent) to add the managed identity as a user in the org and grant **Contributor** at the project scope |
| Service hook permissions | Project-level **Edit project-level information** to register the service hook for Flow B |

You will need:

| Value | Example |
|---|---|
| `ADO_ORG` | `contoso` (from `https://dev.azure.com/contoso/...`) |
| `ADO_PROJECT` | `ProductBacklog` |
| `ADO_WORK_ITEM_TYPE` | `Task` or `User Story` |

> **Important:** Your ADO organization must be backed by the **same Entra tenant** as the subscription where the Logic App is deployed. Otherwise the managed identity cannot authenticate to ADO. Verify in **Organization settings → Microsoft Entra**.

---

## Network considerations (optional)

The default deployment uses **public endpoints** for storage and the Logic App. If your organization requires private networking:

- Storage account → add a **private endpoint** and a `vnet` integration on the Logic App.
- ADO REST API → reachable over the public internet by design; no change needed.
- Microsoft Graph → reachable over the public internet by design; no change needed.

Private networking is out of scope for the default deployment. Open an issue if you need a vnet-integrated variant.

---

## Related Documentation

- Next: [Deployment Guide](DEPLOYMENT.md)
- Architecture: [Architecture Overview](ARCHITECTURE.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
