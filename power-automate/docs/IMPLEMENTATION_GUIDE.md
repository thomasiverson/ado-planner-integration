# Implementation Guide — Planner ↔ Azure DevOps Integration

This guide is for the **solution engineer** who will build, configure, and package the integration flows before handing off to the customer.

---

## Overview

You will build two Power Automate cloud flows inside a Power Platform Solution, then export the solution for deployment to customer environments.

| Flow | Direction | Trigger | Action |
|---|---|---|---|
| **Flow A** | Planner → ADO | New Planner task created | Create ADO work item + write link back |
| **Flow B** | ADO → Planner | ADO work item closed | Complete linked Planner task |

---

## Phase 0 — Prerequisites Setup

Before touching Power Platform, you need the following services configured. Complete each section in order.

### 0.1 Microsoft 365 Group

Every Planner plan belongs to a **Microsoft 365 Group**. You need a group to hold your plan. You can use an existing group or create a new one.

**To create a new Microsoft 365 Group:**

1. Go to [Microsoft 365 Admin Center](https://admin.microsoft.com)
2. In the left nav, select **Teams & groups** → **Active teams & groups**
3. Click **+ Add a Microsoft 365 group**
4. Fill in:
   - **Name:** e.g., `Planner ADO Integration`
   - **Description:** (optional) e.g., "Group for the Planner ↔ ADO integration POC"
   - **Owners:** Add yourself
   - **Members:** Add yourself (and anyone else who needs access)
   - **Group email address:** e.g., `planner-ado-integration` (auto-generated, can customize)
   - **Privacy:** Private (recommended for project work)
5. Click **Create group**
6. Wait a few minutes for the group to provision (Microsoft 365 Groups can take 1–5 minutes to fully propagate)

**To find your Group's Object ID:**

1. Go to [Entra admin center](https://entra.microsoft.com)
2. In the left nav, select **Groups** → **All groups**
3. Find and click on your group (e.g., "All Company")
4. On the group's **Overview** page, the **Object ID** is displayed (a GUID like `00000000-1111-2222-3333-444444444444`)
5. **Copy this value and save it** — you'll paste it into the flow trigger later

> **Note:** The Object ID is NOT shown in the Microsoft 365 Admin Center. You must use the [Entra admin center](https://entra.microsoft.com) to find it.

> **Already have a group?** If you have an existing Microsoft 365 Group you want to use (like "All Company"), that's fine. Just find its Object ID using the steps above.

### 0.2 Planner Plan

A **Plan** is a task board inside Planner. You need one plan to hold the tasks that will sync with Azure DevOps.

**To create a new plan (if you don't have one already):**

1. Go to [Planner](https://planner.cloud.microsoft)
2. Click **+ New plan** (or **New blank plan**)
3. Fill in:
   - **Name:** e.g., `ADO Sync Tasks`
   - **Add to group:** Select the Microsoft 365 Group you created/chose in step 0.1
4. Click **Create**
5. The plan opens — you now have an empty task board

**To find your Plan ID (you'll need this later):**

1. Open your plan in the browser at [planner.cloud.microsoft](https://planner.cloud.microsoft)
2. Look at the URL in your browser's address bar. It will look something like:
   ```
   https://planner.cloud.microsoft/webui/plan/LrAr8fhGzkSPLN8HnuMtDWUAGxid/view/board?tid=...
   ```
3. The Plan ID is the string between `/plan/` and `/view/` — in this example: `LrAr8fhGzkSPLN8HnuMtDWUAGxid`
4. **Copy this value and save it** — you'll paste it into the flow trigger later

> **Already have a plan?** If you already created a plan (like the one you've been using), just grab the Plan ID from the URL.

### 0.3 Azure DevOps Organization and Project

You need an Azure DevOps organization with at least one project.

**If you don't have an Azure DevOps organization:**

1. Go to [dev.azure.com](https://dev.azure.com)
2. Sign in with your organizational account
3. If prompted, create a new organization (e.g., `contoso-dev`)
4. Create a new project (e.g., `PlannerIntegration`)
   - **Visibility:** Private
   - **Work item process:** Agile (recommended) or Scrum
5. Click **Create**

**Note the following values (you'll need them later):**

| Value | Where to Find It | Example |
|---|---|---|
| Organization name | First segment after `dev.azure.com/` in your ADO URL | `contoso-dev` |
| Project name | The project name you created | `PlannerIntegration` |

### 0.4 Summary — Values to Save

Before proceeding, make sure you have these values written down:

| Value | Example | Where You Got It |
|---|---|---|
| **Group Object ID** | `bbd5d6a3-1529-4715-87ec-...` | Microsoft 365 Admin Center → group details |
| **Plan ID** | `LrAr8fhGzkSPLN8HnuMtDWUAGxid` | Planner URL (between `/plan/` and `/view/`) |
| **ADO Organization** | `contoso-dev` | dev.azure.com URL |
| **ADO Project** | `PlannerIntegration` | Azure DevOps project name |
| **ADO Work Item Type** | `Task` | (or User Story, Bug — depends on your process) |

You will use all of these when configuring the flows.

---

## Phase 1 — Power Platform Environment Setup

### 1.1 Create or Select a Power Platform Development Environment

1. Go to [admin.powerplatform.microsoft.com](https://admin.powerplatform.microsoft.com)
2. Under **Environments**, create a new environment or select an existing dev environment
3. Note the environment URL (e.g., `https://org12345.crm.dynamics.com`)

### 1.2 Create the Solution

1. Go to [make.powerapps.com](https://make.powerapps.com)
2. In the top-right environment picker, select your dev environment
3. In the left navigation pane, select **Solutions**
   - If you don't see it, select **…More** at the bottom of the left pane, then select **Solutions**
4. On the command bar at the top, select **New solution**
5. In the panel that appears on the right, fill in:
   - **Display name:** `Planner ADO Integration`
   - **Name:** Auto-generated from the display name (you can edit it to `PlannerAdoIntegration` before saving)
   - **Publisher:** Select an existing publisher from the dropdown, or select **New publisher** to create one for your organization (e.g., display name `YourCompany`, prefix `yc`)
   - **Version:** `1.0.0.0`
6. Click **Save**

> **Note:** The solution now appears in the Solutions list. Click to open it — this is where you will add all components (environment variables, connection references, and flows) in the following steps.

### 1.3 Add Environment Variables

Environment variables let you define configuration values (like organization names and IDs) that can differ between environments. When someone imports the solution, they are prompted to supply values — so the flows work without hard-coded settings.

Add the following environment variables inside the solution:

| Display Name | Type | Default Value |
|---|---|---|
| ADO Organization | Text | *(leave empty — set at import)* |
| ADO Project | Text | *(leave empty)* |
| ADO Work Item Type | Text | `Task` |
| Planner Group ID | Text | *(leave empty)* |
| Planner Plan ID | Text | *(leave empty)* |

**Steps to add an environment variable:**

1. Open your solution in [make.powerapps.com](https://make.powerapps.com)
2. On the command bar, select **+ New** → **More** → **Environment variable**
3. Fill in the fields:
   - **Display name:** e.g., `ADO Organization`
   - **Name (schema name):** This auto-populates with a prefix + a generated suffix (e.g., `new_ADOOrganization` or `yc_ADOOrganization`). The prefix comes from your **solution publisher** and cannot be changed here — it is always `<publisherprefix>_`. You can edit the part after the prefix if you want a shorter name (e.g., change `new_ADOOrganization` to `new_ADOOrg`), but the prefix will always remain.
   - **Data Type:** Select **Text**
   - **Default Value:** Enter the default if one is listed in the table above (e.g., `Task` for ADO Work Item Type). Leave blank otherwise.
   - **Current Value:** Leave blank — this is what will be set per-environment at import time
4. Click **Save**
5. Repeat for each variable in the table above

> **About the schema name prefix:** The prefix (e.g., `new_`) is determined by the publisher you chose when creating the solution in step 1.2. If you used the default publisher, the prefix is `new_`. If you created a custom publisher (recommended) with prefix `yc`, your schema names will be `yc_ADOOrganization`, `yc_ADOProject`, etc. The prefix is consistent across all components in your solution — you don't need to worry about matching exact schema names from this guide, just use the **Display Name** when referencing variables in your flows.

**Where to find the values the administrator will need later:**

| Variable | Where to Find It |
|---|---|
| ADO Organization | The first segment after `dev.azure.com/` in your ADO URL (e.g., `https://dev.azure.com/contoso` → `contoso`) |
| ADO Project | The project name in Azure DevOps |
| ADO Work Item Type | Usually `Task`, `User Story`, or `Bug` — depends on the team's process |
| Planner Group ID | In Microsoft 365 Admin Center → Groups → select the group → copy the **Object Id** |
| Planner Plan ID | Open the plan in Planner → copy the plan ID from the URL (the GUID after `/plan/`) |

> **Important:** Before exporting the solution, remove all **Current Values** so that the importer is prompted to supply their own. Only Default Values (where listed) should ship with the solution.

### 1.4 Add Connection References

Connection references allow the solution to be portable — the actual credentials are supplied at import time rather than being baked in.

Add two connection references inside your solution:

| Display Name | Connector (search for) |
|---|---|
| Planner Connection | **Planner** |
| Azure DevOps Connection | **Azure DevOps** |

> **Note:** The Planner connector is listed as just **"Planner"** in the connector catalog — not "Microsoft Planner." If you search for "Microsoft Planner" you may not find it. Search for **"Planner"** instead.

**Steps to add a connection reference:**

1. Open your solution in [make.powerapps.com](https://make.powerapps.com)
2. On the command bar, select **+ New** → **More** → **Connection Reference**
3. Fill in:
   - **Display name:** e.g., `Planner Connection`
   - **Description:** (optional) e.g., "Used by Planner ↔ ADO integration flows"
   - **Connector:** Click the **Connector** field to open a searchable list. Type `Planner` and select the **Planner** connector (published by Microsoft). For the second reference, search `Azure DevOps` and select **Azure DevOps**.
   - **Connection:** Select an existing connection from the dropdown, or click **+ New connection** to create one and authenticate (see authentication guidance below)
4. Click **Create**
5. Repeat for the second connection reference

> **Tip:** When someone imports this solution into another environment, they will be prompted to map each connection reference to their own connection — so the flows automatically use the importer's credentials.

#### Azure DevOps Authentication Types

When creating the Azure DevOps connection, you will be prompted to choose an authentication type. Here's what each option means and when to use it:

| Auth Type | What It Does | Best For |
|---|---|---|
| **Entra ID** (OAuth) | Signs in as your Microsoft 365 / Entra identity via interactive browser login. No secrets or certificates to manage. | Development, testing, and personal POC environments |
| **Service Principal** | Uses an Entra ID app registration with a **client secret**. The connection runs as the app identity, not a person. | Production / unattended flows where no user is signed in |
| **Client Certificate** | Same as Service Principal but authenticates with an X.509 certificate instead of a client secret. More secure but more complex to set up. | High-security production environments with certificate infrastructure |

**Recommendation:**

- **For development / POC:** Choose **Entra ID**. You sign in with your own account, and it just works — no setup beyond clicking "Sign in." This is the fastest way to get the integration running.
- **For production:** Consider **Service Principal** (or Client Certificate if your organization requires certificate-based auth). A service principal ensures the flows continue to run regardless of individual user accounts being disabled or passwords expiring. You will need to:
  1. Create an App Registration in Entra ID (Azure AD)
  2. Grant it appropriate permissions to your Azure DevOps organization
  3. Generate a client secret (or upload a certificate for Client Certificate auth)
  4. Use those credentials when creating the connection

> **Note:** The Planner connector only supports **default (delegated)** authentication — it always runs as the signed-in user. There is no service principal option for Planner. This means the Planner connection will always be tied to a user account (consider using a shared service account for production).

---

## Phase 2 — Build the Flows

Build each flow **inside the solution** (not as standalone flows).

### Flow A: Planner → Azure DevOps

Follow the detailed step-by-step guide: **[FLOW_A_PLANNER_TO_ADO.md](FLOW_A_PLANNER_TO_ADO.md)**

Summary:
1. Trigger: "When a new task is created" (Planner)
2. Get task details
3. Create ADO work item with mapped fields
4. Update Planner task description with ADO link block

### Flow B: Azure DevOps → Planner

Follow the detailed step-by-step guide: **[FLOW_B_ADO_TO_PLANNER.md](FLOW_B_ADO_TO_PLANNER.md)**

Summary:
1. Trigger: "When a work item is closed" (Azure DevOps) — or scheduled poller
2. Parse Planner Task ID from the work item description
3. Check Planner Task ID is present
4. Mark Planner task as complete (Progress = Completed)

---

## Phase 3 — Data Contract (ID Linking)

This is the most critical design choice. Without reliable ID linking, you will create duplicates and cannot sync status.

### Link Strategy

```
┌──────────────────────────────┐         ┌──────────────────────────────┐
│       Planner Task           │         │       ADO Work Item          │
│                              │         │                              │
│  Description contains:       │         │  Description (or custom      │
│  ---                         │◄───────►│  field) contains:            │
│  ADO_WORK_ITEM_ID: 12345     │         │  PLANNER_TASK_ID: abc-123    │
│  ADO_WORK_ITEM_URL: https:// │         │                              │
│  dev.azure.com/...           │         │                              │
└──────────────────────────────┘         └──────────────────────────────┘
```

### Option A: Description-Based (Minimal, No Schema Changes)

- **In Planner:** Append the ADO link block to the task description
- **In ADO:** Store `PLANNER_TASK_ID` in the work item description

Format appended to Planner task description:
```
---
Linked Azure DevOps Work Item
ADO_WORK_ITEM_ID: <id>
ADO_WORK_ITEM_URL: https://dev.azure.com/<org>/<project>/_workitems/edit/<id>
```

Format appended to ADO work item description:
```
---
PLANNER_TASK_ID: <planner-task-id>
```

### Option B: Custom Field (Production Recommended)

1. In Azure DevOps, go to **Organization Settings → Process**
2. Select the process your project uses (e.g., Agile, Scrum)
3. Select the work item type (e.g., Task)
4. Click **New field**:
   - **Name:** `Planner Task ID`
   - **Type:** Text (single line)
   - **Group:** Add to an existing group or create "Integration"
5. Save

Then in Flow B, read from this custom field instead of parsing the description.

---

## Phase 4 — Test in Development

Follow the [Testing Plan](TESTING_PLAN.md) to validate both flows in your dev environment before packaging.

---

## Phase 5 — Package for Deployment

Once both flows are tested and working in your development environment, you need to **export** the solution as a portable `.zip` file that can be imported into other Power Platform environments (e.g., staging, production, or another tenant).

### 5.1 Publish All Customizations

Publishing makes your latest changes visible to the platform's export process. Any unpublished changes will **not** be included in the exported solution.

1. Open your solution in [make.powerapps.com](https://make.powerapps.com)
2. Select your solution (`Planner ADO Integration`) from the **Solutions** list
3. In the solution view, click **Publish all customizations** (top toolbar)
4. Wait for the "Publishing completed" confirmation

### 5.2 Remove Environment Variable Values

Environment variables have two layers: a **Default Value** (ships with the solution) and a **Current Value** (specific to the current environment). You must clear all Current Values so the importer is prompted to supply their own.

1. Inside the solution, click **Environment variables** in the left panel (or filter the component list)
2. Open each variable one at a time
3. Under **Current Value**, click the **×** or **Remove** button to clear it
4. Verify only the **Default Value** remains (if one was set — e.g., `Task` for ADO Work Item Type)
5. Click **Save**
6. Repeat for all five environment variables

> **Why this matters:** If you leave a Current Value set, the importer's environment will silently use *your* value instead of prompting them — leading to flows that point at the wrong ADO org or Planner plan.

### 5.3 Export the Solution

Exporting packages everything (flows, environment variables, connection references) into a single `.zip` file.

**Via Power Platform UI:**

1. Go to [make.powerapps.com](https://make.powerapps.com) → **Solutions**
2. Find and select `Planner ADO Integration` (check the checkbox next to it)
3. Click **Export** in the top toolbar
4. A side panel will open — click **Next**
5. Choose the export type:
   - **Managed** — Recommended for production. The recipient cannot edit the flows directly; they can only configure environment variables and connections. Updates are applied cleanly via re-import.
   - **Unmanaged** — Choose this if the administrator needs the ability to modify the flows after import. Components can be edited but are harder to upgrade later.
6. Click **Export** and wait for the process to complete (this may take 30–60 seconds)
7. When the download link appears, click it to save the `.zip` file (e.g., `PlannerAdoIntegration_1_0_0_0_managed.zip`)

**Via PAC CLI (scripted):**

If you have the Power Platform CLI installed (see `scripts/01-install-tools.ps1`):

```powershell
.\scripts\02-export-solution.ps1 -SolutionName "PlannerAdoIntegration" -OutputPath ".\solution" -Managed
```

This connects to your dev environment, exports the solution, and saves the `.zip` to the `.\solution` folder.

### 5.4 Source Control the Unpacked Solution

The exported `.zip` is a binary file that's difficult to diff or review in source control. **Unpacking** converts it into a folder of XML/JSON files that can be tracked with Git.

```powershell
.\scripts\04-unpack-pack.ps1 -Action Unpack -ZipPath ".\solution\PlannerAdoIntegration.zip" -OutputFolder ".\solution\unpacked"
```

This creates a structured folder under `.\solution\unpacked\` with individual files for each flow, environment variable, and connection reference. Commit this folder to source control for versioning, code review, and diffing between releases.

---

## Phase 6 — Hand Off to Administrator

Provide the administrator with:

1. The exported solution `.zip` file
2. The [Administrator Handoff Guide](ADMIN_HANDOFF.md)
3. The [Troubleshooting Guide](TROUBLESHOOTING.md) (for their support team)
4. The environment variable values they need to gather (listed in the handoff guide)

---

## Appendix: Field Mapping Reference

### Flow A — Planner to ADO Field Mapping

| Planner Field | ADO Field | Notes |
|---|---|---|
| `title` | `System.Title` | Direct map |
| `description` | `System.Description` | Appended, not replaced |
| `assigneeName` | `System.AssignedTo` | Optional — requires name matching |
| `dueDateTime` | `Microsoft.VSTS.Scheduling.TargetDate` | Optional |
| `planId` | *(none — stored as env var)* | Used for context |
| `id` (task ID) | `System.Description` or custom field | Stored as `PLANNER_TASK_ID` |

### Flow B — ADO to Planner Field Mapping

| ADO Field | Planner Field | Notes |
|---|---|---|
| Work item transitions to closed state | `Progress` = `Completed` | Trigger fires only on close |
| `System.Description` (or custom field) | *(used to locate task)* | Contains `PLANNER_TASK_ID` |

---

## Appendix: Source-of-Truth Rules

| Aspect | Authoritative System | Rationale |
|---|---|---|
| Task creation / intake | Planner | Business users create tasks |
| Execution & status | Azure DevOps | Engineering tracks work here |
| Completion signal | Azure DevOps → Planner | ADO state drives Planner completion |
| Deletion | Manual in both | No automated deletion to prevent data loss |

---

## Related Documentation

- Context: [Solution Overview](SOLUTION_OVERVIEW.md)
- Build step-by-step: [Flow A — Planner to ADO](FLOW_A_PLANNER_TO_ADO.md) · [Flow B — ADO to Planner](FLOW_B_ADO_TO_PLANNER.md)
- Validate: [Testing Plan](TESTING_PLAN.md)
- Hand off: [Administrator Handoff Guide](ADMIN_HANDOFF.md)
- Issues: [Troubleshooting Guide](TROUBLESHOOTING.md)
- Sample WIQL queries: [`samples/ado-wiql/`](../samples/ado-wiql/)
- Back to: [Repository README](../README.md)
