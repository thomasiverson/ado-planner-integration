# Flow A — Planner → Azure DevOps (Step-by-Step Build Guide)

Build this flow **inside your Power Platform Solution** (`PlannerAdoIntegration`).

> **UI Pattern (Modern Designer):** Most fields in this flow appear as dropdown lookups. To set a field to a dynamic value or expression:
> 1. Click the field — a dropdown appears (may show "no items")
> 2. Click **"Enter custom value"** (blue text at the bottom of the dropdown)
> 3. The **Dynamic content** panel appears — select the value you need
>
> If the Dynamic content panel does not appear, you can type an expression directly (e.g., `@{triggerOutputs()?['body/id']}`). Fallback expressions are provided where applicable.

---

## Overview

| Property | Value |
|---|---|
| **Name** | Flow A — Planner to Azure DevOps |
| **Type** | Automated cloud flow |
| **Trigger** | When a new task is created (Planner) |
| **Result** | ADO work item created with Planner task ID in description |

---

## Step 1 — Create the Flow

1. Open your solution in [make.powerapps.com](https://make.powerapps.com)
2. Click **+ New** → **Automation** → **Cloud flow** → **Automated**
3. **Flow name:** `Flow A — Planner to Azure DevOps`
4. **Trigger:** Search for "Planner" → select **When a new task is created**
5. Click **Create**

---

## Step 2 — Configure the Trigger

**When a new task is created**

| Parameter | Value |
|---|---|
| **Group Id** | Your Microsoft 365 Group ID (GUID) |
| **Plan Id** | Your Planner Plan ID (GUID) |

**How to set these values:**

The Group Id and Plan Id fields are dropdown lookups. If the dropdown loads your groups/plans successfully, simply select the correct group and plan from the list. You're done — skip to Step 3.

**If the dropdown shows an error ("could not retrieve values"):**

1. Click the dropdown → scroll to the bottom → click **"Enter custom value"**
2. Paste the actual GUID for your Group or Plan (see below for how to find these)

**Using environment variables in the trigger (optional — may require classic designer):**

If you want the trigger to reference your solution's environment variables:

1. Look for **"Switch to classic designer"** in the top toolbar (or under the **…** menu). Switch to it.
2. In the classic designer, click the Group Id field → **"Enter custom value"**
3. A **Dynamic content** panel should appear below — look for your environment variable (`Planner Group ID`) and select it
4. Repeat for Plan Id

> **Known limitation:** The modern (new) Power Automate designer may not show the Dynamic content panel for trigger lookup fields after selecting "Enter custom value." If you cannot access the classic designer or environment variables still don't appear, paste the GUIDs directly. The administrator importing this solution will need to update these values in the trigger after import (documented in the Administrator Handoff Guide).

**Where to find the GUIDs:**

These values should already be saved from **Phase 0** in the Implementation Guide. If not:

| Value | How to Find It |
|---|---|
| **Group Id** | [Microsoft 365 Admin Center](https://admin.microsoft.com) → **Teams & groups** → **Active teams & groups** → click your group → copy the **Object Id** (a GUID). |
| **Plan Id** | Open your plan at [planner.cloud.microsoft](https://planner.cloud.microsoft). The Plan ID is in the URL between `/plan/` and `/view/` (e.g., `LrAr8fhGzkSPLN8HnuMtDWUAGxid`). |

---

## Step 3 — Get Task Details

1. Below the trigger, click **+ New step** (or the **+** icon between steps)
2. In the "Choose an operation" search box, type **"Get task details"**
3. Under the **Planner** connector, select **Get task details**
4. Click the **Task Id** field — a dropdown appears (may show "no items")
5. Click **"Enter custom value"** (blue text at the bottom of the dropdown)
6. The **Dynamic content** panel appears. Under "When a new task is created", select **Id**

> **Fallback — if the Dynamic content panel does not appear:** Type this expression directly into the text box:
> ```
> @{triggerOutputs()?['body/id']}
> ```

This retrieves the full task including description, checklist, and references.

---

## Step 4 — Initialize Variables

Variables let you store values from earlier steps so you can reuse them later in the flow. You need to add a separate **"Initialize variable"** action for each variable. You'll create three of them.

### 4a — Create the first variable (`varStoryTitle`)

1. Below the "Get task details" action, click **+ New step**
2. In the search box, type **"Initialize variable"**
3. Select **Initialize variable** (under the "Variable" category)
4. Fill in these fields:
   - **Name:** Type `varStoryTitle`
   - **Type:** Select **String** from the dropdown
   - **Value:** Click the Value field → click **"Enter custom value"** → the Dynamic content panel appears → select **Title** (listed under "When a new task is created")

### 4b — Create the second variable (`varStoryDescription`)

1. Below the variable you just created, click **+ New step**
2. Search for **"Initialize variable"** again and select it
3. Fill in these fields:
   - **Name:** Type `varStoryDescription`
   - **Type:** Select **String** from the dropdown
   - **Value:** Click the Value field → click **"Enter custom value"** → the Dynamic content panel appears → select **Description** (listed under "Get task details")

### 4c — Create the third variable (`varPlannerStoryId`)

1. Below the variable you just created, click **+ New step**
2. Search for **"Initialize variable"** again and select it
3. Fill in these fields:
   - **Name:** Type `varPlannerStoryId`
   - **Type:** Select **String** from the dropdown
   - **Value:** Click the Value field → click **"Enter custom value"** → the Dynamic content panel appears → select **Id** (listed under "When a new task is created")

> **Why do this?** Later steps (creating the ADO work item, updating the Planner task) need the story title, description, and ID. Storing them in variables now makes the rest of the flow easier to build and debug.

---

## Step 5 — Create Azure DevOps Work Item

This step creates a work item in Azure DevOps using the task information you stored in variables.

### 5a — Add the action

1. Below your last "Initialize variable" action, click **+ New step**
2. In the search box, type **"Create a work item"**
3. Under the **Azure DevOps** connector, select **Create a work item**

### 5b — Fill in the required fields

Each field appears as a dropdown. Use the same pattern: click the field → click **"Enter custom value"** → then either type a value or select from Dynamic content.

| Field | What to do |
|---|---|
| **Organization Name** | Type your Azure DevOps organization name exactly as it appears in your ADO URL (e.g., if your URL is `https://dev.azure.com/contoso`, type `contoso`) |
| **Project Name** | Type your Azure DevOps project name (e.g., `MyProject`) |
| **Work Item Type** | Type `User Story` |
| **Title** | Click "Enter custom value" → Dynamic content panel appears → select **varStoryTitle** (listed under "Variables") |

### 5c — Set the Description field

1. Click the **Description** field → click **"Enter custom value"**
2. The Dynamic content panel appears. Select **varStoryDescription** (under "Variables")
3. After it's inserted, click at the end of the field and type the following on new lines:

```
---
PLANNER_TASK_ID: 
```

4. After typing `PLANNER_TASK_ID: `, select **varPlannerStoryId** from Dynamic content (under "Variables")

> **What this does:** The description will contain the original Planner task description, plus a marker line with the Planner task ID. Flow B uses this marker to find the linked Planner task when syncing back from ADO.

### 5d — Optional additional fields

Below the Description field, look for **Show advanced options** (or a **"Show all"** link). Click it to reveal more ADO fields you can map:

| ADO Field | What to do |
|---|---|
| **Assigned To** | Leave blank for now (user mapping is complex) |
| **Area Path** | Type your area path if needed, or leave blank for the default |
| **Iteration Path** | Type your iteration path if needed, or leave blank for the default |

---

## Step 6 — Add Error Handling (Recommended)

Error handling ensures that if one step fails, the flow doesn't keep running and making things worse. You're NOT adding a new step here — you're configuring the existing steps to behave correctly when something goes wrong.

### 6a — Add a failure notification (Optional but helpful for debugging)

This adds a separate action that ONLY runs when the ADO step fails, so you get notified.

1. Below the "Create a work item" action, click the **+** icon
2. You should see an option to **Add a parallel branch** — click it
3. In the search box, type **"Send an email"**
4. Select **Send an email (V2)** (under the **Office 365 Outlook** connector)
5. Fill in the fields:
   - **To:** Type your email address
   - **Subject:** Type `Flow A — Failed to create ADO work item`
   - **Body:** Type `The flow failed to create an ADO work item. Check the flow run history for details.`
6. Now configure THIS action to only run on failure:
   - Click the **three dots (⋯)** on the "Send an email" action
   - Select **Configure run after**
   - UNcheck **is successful**
   - ✅ Check **has failed**
   - Click **Done**

> **Result:** If Step 5 succeeds → the flow ends successfully. If Step 5 fails → the email action runs and notifies you.

> **Don't have Outlook?** You can use **Post message in a chat or channel (Teams)** instead of "Send an email." Same setup — just search for "Teams" in the action search.

---

## Step 7 — Save and Test

1. Click **Save** in the top-left corner
2. Once saved, the flow is **live** — it will trigger automatically every time a new task is created in your configured Planner plan
3. To test: open your Planner plan in another browser tab and create a new task
4. Wait **1–3 minutes** (the trigger polls for new tasks on a schedule, it's not instant)
5. Come back to Power Automate and check the **flow run history** to verify it succeeded
6. Open Azure DevOps and confirm the User Story was created with the correct title and description

> **How to check flow run history:** From the flow editor, click the **←** back arrow to go to the flow details page. You'll see a list of recent runs with green checkmarks (success) or red X's (failure). Click any run to see the step-by-step details.

> **To stop the flow temporarily:** Click **Turn off** in the flow's top toolbar. Click **Turn on** to re-enable it.

---

## Complete Flow Diagram

```
┌─────────────────────────────────────┐
│ Trigger: When a new task is created │
│ (Planner)                           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Get task details (Planner)          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Initialize variables                │
│ - varStoryTitle                     │
│ - varStoryDescription               │
│ - varPlannerStoryId                 │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ Create a work item (Azure DevOps)   │
│ - Title = varStoryTitle             │
│ - Description = desc + story ID     │
│ - Type = User Story                 │
└──────────────┬──────────────────────┘
               │
          (done — flow ends)
```

---

## Known Limitations

| Limitation | Details |
|---|---|
| **No back-link in Planner** | The Planner connector's "Update task details" action writes to the `description` field, but the new Planner UI (planner.cloud.microsoft) does not display updates made through this API. A direct Microsoft Graph API call is required for production. |
| **Polling delay** | The trigger checks for new tasks every 1–3 minutes. Work items won't appear in ADO instantly. |
| **Delegated auth only** | The Planner connector only supports delegated (user) authentication. The flow runs as the connection owner. |

---

## Troubleshooting This Flow

| Symptom | Cause | Fix |
|---|---|---|
| Flow doesn't trigger | Wrong Group/Plan ID | Verify the GUIDs pasted in the trigger |
| Flow takes several minutes | Polling interval | Normal — trigger polls every 1–3 minutes |
| ADO work item not created | Connection auth expired | Re-authenticate the ADO connection reference |
| "Access denied" on ADO | Insufficient permissions | Ensure connection account has Contributor role in the ADO project |
| Duplicate work items | Flow triggered multiple times | Add a condition to check if `PLANNER_TASK_ID:` already exists in ADO |

---

## Related Documentation

- Back: [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- Next: [Flow B — ADO to Planner](FLOW_B_ADO_TO_PLANNER.md)
- Validate: [Testing Plan](TESTING_PLAN.md)
- Issues: [Troubleshooting Guide](TROUBLESHOOTING.md)
- Back to: [Repository README](../README.md)
