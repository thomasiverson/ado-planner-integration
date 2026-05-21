# Managed Identity Setup

The user-assigned managed identity (UAMI) needs three distinct authorizations to do its job. The Bicep template handles one; you grant the other two manually (or via the scripts).

---

## Audience

The engineer or Azure / Entra / ADO administrator completing post-deployment authorization.

---

## Identity overview

| Identity | Created by | Used for |
|---|---|---|
| UAMI `uami-plannerado-<suffix>` | Bicep ([`infra/modules/identity.bicep`](../infra/modules/identity.bicep)) | All outbound HTTP calls from both workflows |

The UAMI has both an **Object ID** (also called Principal ID — used for role assignments) and a **Client ID** (used inside the Logic App `appsettings` so HTTP actions can specify which identity to use). Both are emitted as Bicep outputs.

---

## Step 1 — Storage (Azure RBAC, automatic)

Handled by Bicep — the UAMI is granted the following on the Logic App's backing storage account:

| Role | Why |
|---|---|
| Storage Blob Data Owner | Logic Apps runtime stores workflow state & history blobs here |
| Storage Queue Data Contributor | Used internally for trigger fanout |
| Storage Table Data Contributor | Used internally for run state |

No action needed — this is provisioned by [`infra/modules/storage.bicep`](../infra/modules/storage.bicep).

---

## Step 2 — Microsoft Graph (app role assignments)

The workflows call Microsoft Graph to read/update Planner tasks. The UAMI needs **application permissions** (delegated permissions don't apply to managed identities).

Required Graph app roles:

| App role | Purpose |
|---|---|
| `Tasks.ReadWrite.All` | Read new Planner tasks (Flow A) and mark tasks complete (Flow B) |
| `Group.Read.All` | Resolve the Planner plan via its owning Microsoft 365 Group |

### Granting via the script (recommended)

```powershell
./scripts/02-grant-graph-permissions.ps1 -ManagedIdentityObjectId <objectId>
```

The script uses the Microsoft Graph PowerShell SDK to add app role assignments to the UAMI's service principal. **Requires Global Admin or Privileged Role Administrator** for the consent step.

### Granting manually (Azure CLI)

```powershell
$mi = '<managed-identity-object-id>'
$graphSp = (az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv)

# Tasks.ReadWrite.All
$tasksRoleId = (az ad sp show --id $graphSp --query "appRoles[?value=='Tasks.ReadWrite.All'].id | [0]" -o tsv)
az rest --method POST `
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$mi/appRoleAssignments" `
  --body (@{ principalId = $mi; resourceId = $graphSp; appRoleId = $tasksRoleId } | ConvertTo-Json)

# Group.Read.All
$groupRoleId = (az ad sp show --id $graphSp --query "appRoles[?value=='Group.Read.All'].id | [0]" -o tsv)
az rest --method POST `
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$mi/appRoleAssignments" `
  --body (@{ principalId = $mi; resourceId = $graphSp; appRoleId = $groupRoleId } | ConvertTo-Json)
```

### Verifying the grants

```powershell
az rest --method GET --uri "https://graph.microsoft.com/v1.0/servicePrincipals/<mi-object-id>/appRoleAssignments"
```

You should see two entries, one per role.

---

## Step 3 — Add the managed identity to Azure DevOps

ADO authentication for managed identities works by:

1. The MI requests a token for ADO's resource ID (`499b84ac-1321-427f-aa17-267ca6975798`).
2. ADO validates the token (issuer must match an Entra tenant federated with the ADO org).
3. ADO authorizes based on the MI's membership in the org and project.

So the MI must be **added as a user** to the ADO organization.

### Via the ADO UI

1. Open `https://dev.azure.com/<your-org>/_settings/users`.
2. Click **Add users**.
3. In **Users or Groups**, type the UAMI's display name (e.g., `uami-plannerado-xxxxx`) or its Object ID. The picker will resolve it as a service principal.
4. Set **Access level** = **Basic**.
5. Set **Add to projects** = the target project.
6. Set **Azure DevOps Groups** = `Project Contributors` (or higher if you need to register service hooks under this identity).
7. Click **Add**.

### Project-level role for work item creation

The MI also needs **Contributor** at the project scope:

1. Open `https://dev.azure.com/<your-org>/<your-project>/_settings/permissions`.
2. Select the **Contributors** group → **Members** → **Add**.
3. Add the UAMI.

### Permissions required

| Operation | Permission |
|---|---|
| Create work item (Flow A) | Contributor on the project |
| Read work item (Flow B → lookup before update) | Contributor on the project |
| Update work item description (Flow A — write back link) | Contributor on the project |

> **Tenant alignment check:** The ADO org must be backed by the same Entra tenant as the subscription holding the UAMI. Verify under `https://dev.azure.com/<org>/_settings/organizationAad`. If they don't match, the MI cannot acquire a valid token.

---

## Step 4 — Wire the identity into the Logic App (automatic)

Bicep already assigns the UAMI to the Logic App and writes `MANAGED_IDENTITY_CLIENT_ID` into the app's `appsettings`. The workflow HTTP actions reference it via `@appsetting('MANAGED_IDENTITY_CLIENT_ID')`.

No action needed.

---

## Revoking access

To remove the integration cleanly:

```powershell
# Revoke Graph app role assignments
./scripts/02-grant-graph-permissions.ps1 -ManagedIdentityObjectId <objectId> -Revoke

# Remove from ADO: UI → Organization settings → Users → select MI → Remove
# Delete Azure resources
az group delete --name rg-plannerado --yes
```

---

## Related Documentation

- Deploy: [Deployment Guide](DEPLOYMENT.md)
- Workflow internals (how the auth is actually used): [Workflow A](WORKFLOW_A_PLANNER_TO_ADO.md) · [Workflow B](WORKFLOW_B_ADO_TO_PLANNER.md)
- Common auth failures: [Troubleshooting → Authentication](TROUBLESHOOTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
