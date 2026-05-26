# Azure Deployment Rules — MCAPS Development Subscription

> **Audience:** Anyone deploying new workloads (Function Apps, App Services, Container Apps, AKS, SQL, Storage, etc.) into the **Development** subscription under the MCAPS tenant.
> **Purpose:** Document the management-group policies and platform behaviors that silently rewrite or block deployments, plus the deployment patterns that are known to work end-to-end. Following this guide will save you the 15+ iterative deploy cycles it took to discover them the first time.

---

## 1. Hard rules enforced by Management Group policies

These are policy **`modify`** / **`deny`** effects. They run *after* your ARM/Bicep deploy completes and either flip properties or block the request. You cannot opt out — design around them up front.

### 1.1 Storage Accounts
| Property | Policy effect | Implication |
|---|---|---|
| `allowSharedKeyAccess` | Forced to `false` | **Breaks classic Y1 Consumption Function Apps** (file-share mount requires shared keys). Breaks `AzureWebJobsStorage` connection strings. |
| `publicNetworkAccess` | Forced to `Disabled` | Even when Bicep says `Enabled`, the policy flips it. **Storage is unreachable from the public internet** — clients must use Private Endpoints or trusted-Microsoft-services bypass. |
| `networkAcls.defaultAction` | Forced to `Deny` | Must be `Deny` in your template — drift detection will keep flipping it. |
| `minimumTlsVersion` | Forced to `TLS1_2` | Set explicitly to silence drift warnings. |

**Design implication:** Every storage account needs Private Endpoints (blob + queue + table + file for Functions) and a VNet to host them. No "quick storage account for testing" — it'll be unreachable.

### 1.2 Azure SQL
| Property | Policy effect | Implication |
|---|---|---|
| `publicNetworkAccess` | Forced to `Disabled` | SQL is reachable **only** via Private Endpoint. |
| Firewall rules (`firewallRules`) | **Blocked** while public access is Disabled | `az sql server firewall-rule create` returns `FirewallChangesDeniedBecausePublicEndpointDisabled`. |
| VNet rules (`virtualNetworkRules`) | **Blocked** while public access is Disabled | Same error. Service-endpoint pattern doesn't work either. |
| `administrators` (Entra-only) | Set this; SQL auth admin is disabled in practice | Use Entra ID admins exclusively. |

**Design implication:** Service endpoints + firewall rules are **dead patterns** in this subscription. Always use Private Endpoint for SQL access. Schema/seed apply requires running tools **inside the VNet** — your laptop's `sqlcmd` will time out.

### 1.3 App Service Plans
| Constraint | Detail |
|---|---|
| SKU sticky per RG | Once a plan SKU is used in a resource group, conflicting SKUs are blocked (`PricingTierNotAllowedInThisResourceGroup` / error 04114). E.g., a deleted Y1 plan still blocks `FlexConsumption` creation. |
| Fix | `az appservice plan delete -g <rg> -n <plan>` then redeploy. If repeated, deploy into a fresh RG. |

### 1.4 Flex Consumption Function Apps
| Constraint | Detail |
|---|---|
| Storage auth | **Must use managed identity** (`AzureWebJobsStorage__accountName` + `blobServiceUri/queueServiceUri/tableServiceUri`). No connection strings — shared keys are disabled. |
| Required role assignments on storage (to Function App's system-assigned MI) | • Storage Blob Data Owner `b7e6dc6d-f1e8-4753-8033-0f276bb0955b`<br>• Storage Queue Data Contributor `974c5e8b-45b9-4653-ba55-5f855dd0fb88`<br>• Storage Table Data Contributor `0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3`<br>**All three are required even if you don't use queues/tables** — the Functions host needs them for leases. |
| Basic auth Kudu | **Unsupported** on Flex Consumption. `az functionapp deployment list-publishing-credentials` fails. Use `az webapp log tail` or App Insights for diagnostics. |
| Oryx remote build | Fails silently in this environment. Always build locally and zip-deploy (`func azure functionapp publish <app> --typescript` with `node_modules` included; do not exclude in `.funcignore`). |

### 1.5 Resource provider registrations
Some RPs are not auto-registered. Check and register once per subscription:
- `Microsoft.ContainerInstance` (needed for the ACI sidecar pattern below)
- `Microsoft.App` (Container Apps + Flex Consumption environments)
- `Microsoft.OperationalInsights`, `Microsoft.Insights` (App Insights)
- `Microsoft.Sql`
- `Microsoft.Network`

`deploy.ps1` auto-registers `Microsoft.ContainerInstance`. Pattern:
```powershell
$rpState = az provider show -n Microsoft.ContainerInstance --query registrationState -o tsv
if ($rpState -ne 'Registered') {
  az provider register -n Microsoft.ContainerInstance -o none
  do { Start-Sleep 10; $rpState = az provider show -n Microsoft.ContainerInstance --query registrationState -o tsv } while ($rpState -ne 'Registered')
}
```

---

## 2. The canonical VNet layout

Every non-trivial workload in this subscription needs a VNet. The pattern that works:

```
VNet 10.40.0.0/22
├─ snet-functions   10.40.0.0/24   delegated: Microsoft.App/environments
│                                  (Flex Consumption / Container App env integration)
├─ snet-pe          10.40.1.0/24   privateEndpointNetworkPolicies: Disabled
│                                  (all Private Endpoints live here)
└─ snet-aci         10.40.2.0/24   delegated: Microsoft.ContainerInstance/containerGroups
                                   (one-shot sidecars for schema apply, migrations, etc.)
```

**Rules:**
- Do **not** put `Microsoft.Sql` (or any other) service endpoint on `snet-functions`. The combination with `vnetRouteAllEnabled: true` confuses SQL's source-IP detection and breaks `AllowAllAzureServices` firewall rules.
- Each delegated subnet can host **only one** delegation type. ACI cannot share `snet-functions` or `snet-pe`.
- Add subnets as needed (`snet-bastion`, `snet-agents`, etc.) within the `/22` block.

---

## 3. Required Private DNS zones

Whenever you add a service with a Private Endpoint, you also need the matching Private DNS zone, linked to your VNet, and a `privateDnsZoneGroup` on the PE. Common zones:

| Service | Zone | PE `groupId` |
|---|---|---|
| Blob storage | `privatelink.blob.core.windows.net` | `blob` |
| Queue storage | `privatelink.queue.core.windows.net` | `queue` |
| Table storage | `privatelink.table.core.windows.net` | `table` |
| File storage | `privatelink.file.core.windows.net` | `file` |
| Azure SQL | `privatelink${environment().suffixes.sqlServerHostname}` (= `privatelink.database.windows.net`) | `sqlServer` |
| Key Vault | `privatelink.vaultcore.azure.net` | `vault` |
| App Configuration | `privatelink.azconfig.io` | `configurationStores` |
| Container Registry | `privatelink.azurecr.io` | `registry` |
| Cosmos DB (SQL) | `privatelink.documents.azure.com` | `Sql` |
| Service Bus | `privatelink.servicebus.windows.net` | `namespace` |
| Cognitive Services | `privatelink.cognitiveservices.azure.com` | `account` |

Pattern (Bicep):
```bicep
resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' = { name: 'privatelink.<service>'; location: 'global' }
resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: zone
  name: 'link-${uniqueString(vnetId)}'
  location: 'global'
  properties: { virtualNetwork: { id: vnetId }; registrationEnabled: false }
}
resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: pe
  name: 'default'
  properties: { privateDnsZoneConfigs: [ { name: 'default'; properties: { privateDnsZoneId: zone.id } } ] }
}
```

---

## 4. CORS for VSS / extension scenarios

If your backend serves a VSTS/ADO extension iframe:

- The iframe's `Origin` is `https://<publisherId-lowercase>.gallerycdn.vsassets.io` — not `dev.azure.com`.
- Azure Functions intercepts the OPTIONS preflight **at the platform layer** using `siteConfig.cors.allowedOrigins`. If the origin isn't there, in-code CORS handling never runs.
- You must set **both**: platform CORS (`siteConfig.cors.allowedOrigins`) **and** any in-code allow-list env var.
- Hot-fix without redeploy: `az functionapp cors add -g <rg> -n <func> --allowed-origins "https://<publisher-lower>.gallerycdn.vsassets.io"`. Applies immediately, no restart.

---

## 5. The ACI sidecar pattern (for any "I need to reach a private resource from my laptop")

The single most useful pattern in this environment: a one-shot container in `snet-aci` runs the action (schema apply, migration, secret bootstrap, blob upload) from **inside the VNet**, using a short-lived Entra token from your CLI session.

### What works
- **Image:** `mcr.microsoft.com/powershell:latest` (Linux pwsh). Has TLS, package manager, and access to `Install-Module SqlServer` which uses `Microsoft.Data.SqlClient` (accepts bearer tokens natively).
- **Deploy spec:** YAML file passed via `az container create --file`. Required because base64'd payloads exceed Windows' 8K command-line limit on `--command-line`.
- **Payload smuggling:** base64-encode the script and any data; pass via ACI `secureValue` env vars; decode + execute in the container. Avoids YAML/bash/PowerShell quoting hell entirely.
- **Auth:** Caller runs `az account get-access-token --resource https://database.windows.net` (or other audience) and passes the JWT to the container.

### What does NOT work (avoid these traps)
| Approach | Why it fails |
|---|---|
| `mcr.microsoft.com/mssql-tools18:latest` | Tag does not exist on MCR. |
| `mcr.microsoft.com/mssql-tools` (sqlcmd 17) | `-P` flag capped at 128 chars — JWT bearer token is ~2200 chars. |
| `mcr.microsoft.com/mssql/server` (sqlcmd 18) | Throws cryptic `'edit.com'` env-var error; also lacks curl/tar. |
| `go-sqlcmd v1.10.0 --authentication-method=ActiveDirectoryServicePrincipalAccessToken` | Broken in v1.10.0 — always reports "Must provide 'password' parameter" regardless of `-P` / `SQLCMDPASSWORD`. |
| `ubuntu:22.04` / any `docker.io/*` image from ACI | Anonymous Docker Hub pulls are rate-limited; ACI returns `RegistryErrorResponse index.docker.io`. Stick to MCR. |
| Inline `--command-line` on `az container create` | Hits Windows 8K cmd-line limit when payload is base64'd. Use `--file` YAML. |
| Running `sqlcmd` from your laptop with a temporary firewall rule | Blocked by policy (see §1.2). |

### Reference: working ACI YAML spec (Bicep/deploy.ps1)
See [solutions/extensions/intel-workitem-controls/infra/deploy.ps1](solutions/extensions/intel-workitem-controls/infra/deploy.ps1) lines ~160-230 for the complete pattern: PowerShell here-string → CRLF→LF normalize → base64 → YAML with `secureValue` env vars → `pwsh -NoProfile -File`.

---

## 6. Schema/seed migration practices

When the ACI sidecar reruns (or when you redeploy), every SQL statement must be idempotent. Drop-in patterns:

```sql
-- Schema
IF SCHEMA_ID('lookup') IS NULL EXEC('CREATE SCHEMA lookup');

-- Table
IF OBJECT_ID('lookup.PickList','U') IS NULL CREATE TABLE lookup.PickList (...);

-- Index
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name='IX_PickList_List' AND object_id=OBJECT_ID('lookup.PickList'))
CREATE INDEX IX_PickList_List ON lookup.PickList(ListName, IsActive);

-- Database user
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='<MI_NAME>')
    CREATE USER [<MI_NAME>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<MI_NAME>];  -- always safe; no-op if already member

-- Seed data
MERGE lookup.Foo AS t
USING (VALUES (...)) AS s(col1, col2)
   ON t.col1 = s.col1
WHEN NOT MATCHED THEN INSERT (col1, col2) VALUES (s.col1, s.col2);
```

Avoid `CREATE INDEX` without a guard, `INSERT` without a `WHERE NOT EXISTS` or `MERGE`, and `CREATE USER` without guarding.

---

## 7. Recommended deployment pipeline shape

For any new service:

1. **Bicep modules:** one per logical service (`vnet.bicep`, `storage.bicep`, `sql.bicep`, `appservice.bicep`, `private-endpoints.bicep`). Compose in `main.bicep`.
2. **`deploy.ps1` orchestrator:**
   - Tool checks (az, func, node, npm — drop sqlcmd; use ACI sidecar instead).
   - `az group create`.
   - `az deployment group create` (capture outputs to `$out`).
   - Auto-register required RPs.
   - Acquire any Entra tokens needed for data-plane bootstrap (`az account get-access-token --resource <audience>`).
   - Run ACI sidecar for schema/data bootstrap (if needed).
   - Build app locally → zip-deploy (or `func azure functionapp publish`).
   - Smoke test (curl the health endpoint).
3. **`infra/main.parameters.json`** for env-specific values; pass `-Env test|prod` as a CLI param.
4. **Outputs from `main.bicep`:** every name + connection string + subnet ID downstream steps need (the orchestrator should never have to `az resource show` again).

---

## 8. Identity & RBAC quick reference

- **Functions/App Services:** enable system-assigned managed identity. Grant it data-plane roles on storage, SQL, Key Vault, etc.
- **SQL:** create the MI as a database user via `CREATE USER [<MI-name>] FROM EXTERNAL PROVIDER`, then `ALTER ROLE db_datareader/db_datawriter ADD MEMBER`. No SQL auth.
- **ADO orgs:** to let a Function App MI call ADO APIs, add it as a member to the org (Organization Settings → Users → Add → search by Function App name). Then request token with audience `499b84ac-1321-427f-aa17-267ca6975798`.

---

## 9. Common GUIDs (built-in role IDs)

| Role | GUID |
|---|---|
| Storage Blob Data Owner | `b7e6dc6d-f1e8-4753-8033-0f276bb0955b` |
| Storage Blob Data Contributor | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |
| Storage Queue Data Contributor | `974c5e8b-45b9-4653-ba55-5f855dd0fb88` |
| Storage Table Data Contributor | `0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3` |
| Key Vault Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` |
| Key Vault Crypto User | `12338af0-0e69-4776-bea7-57ae8d297424` |
| Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |
| Contributor | `b24988ac-6180-42a0-ab88-20f7382dd24c` |

ADO audience for Entra tokens: `499b84ac-1321-427f-aa17-267ca6975798`.
SQL audience: `https://database.windows.net`.
Storage audience: `https://storage.azure.com`.
Key Vault audience: `https://vault.azure.net`.

---

## 10. CLI flag drift to watch

The az CLI deprecates flags faster than docs update. Recent ones that bit us:

| Old | New |
|---|---|
| `--ignore-missing-vnet-service-endpoint` | `--ignore-missing-endpoint` (now a boolean switch) |
| `az functionapp deployment list-publishing-credentials` on Flex | Unsupported. Use `az webapp log tail`. |
| `az devops invoke --area ...` | Discovery is flaky. Use direct REST with `az account get-access-token --resource 499b84ac-...`. |

---

## 11. Deployment checklist (copy this for new workloads)

- [ ] Identified all PaaS services needed → for each, planned Private Endpoint + private DNS zone + zone link.
- [ ] VNet with at least `snet-pe` (PE), `snet-functions` or `snet-app` (delegated to compute), `snet-aci` (delegated to ACI) if any data-plane bootstrap is needed.
- [ ] Storage account configured: `allowSharedKeyAccess: false`, `publicNetworkAccess: 'Disabled'`, `networkAcls.defaultAction: 'Deny'`.
- [ ] Function App / App Service uses **system-assigned MI**, with all three storage roles granted.
- [ ] App settings use `__accountName` / `__blobServiceUri` pattern, **no** connection strings.
- [ ] CORS configured at the platform layer (`siteConfig.cors.allowedOrigins`) if browser clients call it.
- [ ] SQL `publicNetworkAccess: 'Disabled'`, Entra-only admin, no firewall/VNet rules.
- [ ] All SQL DDL is idempotent (see §6).
- [ ] All required resource providers pre-registered.
- [ ] `deploy.ps1` outputs everything downstream steps need; idempotent on re-run.
- [ ] Smoke test added at the end of `deploy.ps1`.
- [ ] Tested by running `deploy.ps1` twice in a row — second run is no-op + success.

---

**Last verified:** 2026-05-25 against `intel-workitem-controls` end-to-end deploy in `rg-ado-customization`.
