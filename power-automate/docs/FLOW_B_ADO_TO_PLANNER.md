# Flow B — Azure DevOps → Planner (Step-by-Step Build Guide)

Build this flow **inside your Power Platform Solution** (`PlannerAdoIntegration`).

---

## Overview

| Property | Value |
|---|---|
| **Name** | Flow B — Azure DevOps to Planner |
| **Type** | Automated cloud flow (Option 1) or Scheduled flow (Option 2) |
| **Trigger** | Work item closed (Option 1) or Recurrence schedule (Option 2) |
| **Result** | Planner task marked complete when ADO work item is closed |

This guide covers **both options**. Use Option 1 if the ADO connector trigger is available; fall back to Option 2 if it is not.

---

## Option 1 — Event-Driven (Preferred)

### Step 1 — Create the Flow

1. Open your solution in [make.powerapps.com](https://make.powerapps.com)
2. Click **+ New** → **Automation** → **Cloud flow** → **Automated**
3. **Flow name:** `Flow B — Azure DevOps to Planner`
4. **Trigger:** Search for "Azure DevOps" → select **When a work item is closed**
5. Click **Create**

> **Why "When a work item is closed" and not "When a work item is updated"?** The "updated" trigger fires on ANY change (comments, links, field edits) and the State field value in its output is unreliable for filtering. The "closed" trigger fires ONLY when a work item transitions to a closed state — eliminating the need for a State condition entirely.

### Step 2 — Configure the Trigger

**When a work item is closed**

| Parameter | Value |
|---|---|
| **Organization Name** | Your ADO org (e.g., `<your-org>`) |
| **Project Name** | Your ADO project |
| **Work Item Type** | `User Story` (or whatever Flow A creates) |
| **Closed State** | `Closed` (Agile) or `Done` (Scrum) |

> **What state does your project use?** This depends on your ADO process template:
> - **Scrum** → `Done`
> - **Agile** → `Closed`
> - **CMMI** → `Closed`
>
> You can specify multiple states comma-separated (e.g., `Done, Closed, Completed`).

### Step 3 — Initialize the Variable

> **Important:** "Initialize variable" can ONLY be placed at the top level of a flow — NOT inside a condition or loop.

1. Below the trigger, click **+ New step**
2. Search for **"Initialize variable"** and select it
3. Fill in:
   - **Name:** Type `varPlannerStoryId`
   - **Type:** Select **String**
   - **Value:** Leave blank (you'll set it after the Compose actions below)

### Step 4 — Extract Planner Story ID from Description

Flow A embedded `PLANNER_TASK_ID: <id>` in the ADO work item's description. You need to parse it out using two **Compose** actions, then store the result in `varPlannerStoryId`.

These actions go at the **top level** of the flow (below Initialize variable, NOT inside any condition).

**4a — Add first Compose action (Compose - Split):**

1. Below Initialize variable, click **+ New step**
2. Search for **"Compose"** and select it (under "Data Operation")
3. Click the **Inputs** field → switch to the **Expression** tab
4. Paste this expression exactly, then click **OK** (or **Add**):
   ```
   split(coalesce(triggerOutputs()?['body/fields/System_Description'], 'NOTFOUND'), 'PLANNER_TASK_ID:')
   ```
5. Rename this action: click the **⋯** → **Rename** → type `Compose - Split`

> **Field path notes:**
> - The field is `System_Description` (underscore), NOT `System.Description` (dot) — Power Automate flattens dots to underscores in the trigger output.
> - Fields live under `body/fields/`, not at the body root.
> - `coalesce(..., 'NOTFOUND')` protects against null descriptions — if it returns `NOTFOUND` at runtime, your field path is wrong.

**4b — Add second Compose action (Compose - Extract ID):**

1. Below the first Compose, click **+ New step**
2. Search for **"Compose"** again and select it
3. Click the **Inputs** field → switch to the **Expression** tab
4. Paste this expression exactly, then click **OK**:
   ```
   trim(first(split(trim(outputs('Compose_-_Split')[1]), ' ')))
   ```
5. Rename this action: click **⋯** → **Rename** → type `Compose - Extract ID`

> **What these do:**
> - **Compose - Split** splits the description at `PLANNER_TASK_ID:`, giving you a 2-element array. Index `[1]` is the part AFTER the marker (e.g., `" nGZJ706fW0CqyYzwHdsy_WUAAWIr </p>"`).
> - **Compose - Extract ID** trims that string, splits by space, and takes the first chunk — stripping off the trailing `</p>` HTML tag that Flow A's HTML description leaves behind. Result: a clean Planner task ID like `nGZJ706fW0CqyYzwHdsy_WUAAWIr`.

**4c — Set the variable to the extracted value:**

1. Below Compose - Extract ID, click **+ New step**
2. Search for **"Set variable"** and select it
3. Fill in:
   - **Name:** Select **varPlannerStoryId** from the dropdown
   - **Value:** Click inside the Value field → Dynamic content appears → select **Outputs** (listed under "Compose - Extract ID")

### Step 5 — Condition: Is Planner Story ID Present?

This prevents errors when a work item doesn't have a linked Planner task (e.g., one created directly in ADO without Flow A).

1. Below Set variable, click **+ New step**
2. Search for **"Condition"** and select it

**Set the left side:**

3. Click inside the left box — Dynamic content appears — select **varPlannerStoryId** (listed under "Variables")

**Set the operator:**

4. Change the operator dropdown to **is not equal to**

**Set the right side:**

5. Leave the right box **empty** (don't type anything — this checks if the variable is blank)

### Step 6 — If Yes: Complete the Planner Task

In the **If yes** branch of the condition:

1. Click **+ Add an action** (inside the "If yes" box)
2. Search for **"Update a task"**
3. Under the **Planner** connector, select **Update a task**
4. Click the **Task Id** field → click **"Enter custom value"** → Dynamic content appears → select **varPlannerStoryId** (under "Variables")
5. Click the **Progress** field → select **Completed** from the dropdown

> Setting Progress to "Completed" marks the task as done in Planner.

### Step 7 — Save and Test

1. Click **Save**
2. In Azure DevOps, take a User Story that was created by Flow A (its description contains `PLANNER_TASK_ID:`) and move it to the **Closed** state
3. Wait ~30 seconds for the trigger to fire (the "closed" trigger is a polling trigger)
4. Check the run history in Power Automate — all steps should be green
5. Verify the linked Planner task is now marked **Completed**

> **To re-test the same work item:** Set it back to Active in ADO, then close it again. The trigger only fires on transitions INTO a closed state.

---

## Option 2 — Scheduled Poller (Fallback)

Use this if the ADO "When a work item is closed" trigger is not available or unreliable in your environment.

### Step 1 — Create the Flow

1. In your solution, click **+ New** → **Automation** → **Cloud flow** → **Scheduled**
2. **Flow name:** `Flow B — Azure DevOps to Planner (Poller)`
3. **Frequency:** Every 5 minutes (adjust based on needs)
4. Click **Create**

### Step 2 — Initialize Watermark Variable

The watermark tracks the last poll time to avoid re-processing items.

Add action: **Initialize variable**

| Parameter | Value |
|---|---|
| **Name** | `varLastRunTime` |
| **Type** | String |
| **Value** | `@{addMinutes(utcNow(), -10)}` |

> For a production implementation, store the watermark in a Dataverse table or environment variable and update it after each successful run.

### Step 3 — Query ADO for Recently Completed Work Items

Add action: **Azure DevOps → Send an HTTP request to Azure DevOps**

| Parameter | Value |
|---|---|
| **Organization Name** | Environment variable `ADO_ORG` |
| **HTTP Method** | `POST` |
| **Relative URI** | `@{outputs('Get_ADO_PROJECT')}/_apis/wit/wiql?api-version=7.1` |
| **Body** | See below |

**Request body (WIQL query):**

```json
{
  "query": "SELECT [System.Id], [System.State], [System.Description] FROM WorkItems WHERE [System.TeamProject] = '@currentProject' AND [System.WorkItemType] = 'Task' AND [System.State] = 'Done' AND [System.ChangedDate] >= '@{variables('varLastRunTime')}' ORDER BY [System.ChangedDate] DESC"
}
```

> Replace `'Task'` with your work item type. Replace `'Done'` with your completed state.

### Step 4 — Parse the WIQL Response

Add action: **Parse JSON**

| Parameter | Value |
|---|---|
| **Content** | Dynamic content: `Body` (from HTTP request) |
| **Schema** | See below |

**Schema:**
```json
{
  "type": "object",
  "properties": {
    "workItems": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "integer" },
          "url": { "type": "string" }
        }
      }
    }
  }
}
```

### Step 5 — Loop Through Results

Add action: **Apply to each**

| Parameter | Value |
|---|---|
| **Select an output from previous steps** | `workItems` (from Parse JSON) |

### Step 6 — Get Full Work Item Details (Inside Loop)

Add action: **Azure DevOps → Get work item details**

| Parameter | Value |
|---|---|
| **Organization Name** | Environment variable `ADO_ORG` |
| **Project Name** | Environment variable `ADO_PROJECT` |
| **Id** | Dynamic content: `id` (from current item) |

### Step 7 — Extract Planner Task ID and Complete (Inside Loop)

Follow the same logic as Option 1, Steps 4–6:
1. Extract `PLANNER_TASK_ID` from the description or custom field
2. Check if it's non-empty
3. Update the Planner task with `percentComplete = 100`

### Step 8 — Update Watermark (After Loop)

If using a stored watermark, update it to `utcNow()` after the loop completes.

---

## Complete Flow Diagram (Option 1)

```
┌───────────────────────────────────────┐
│ Trigger: When a work item is closed   │
│ (Azure DevOps) — Closed State=Closed  │
└──────────────┬────────────────────────┘
               │
               ▼
┌───────────────────────────────────────┐
│ Initialize variable: varPlannerStoryId│
└──────────────┬────────────────────────┘
               │
               ▼
┌───────────────────────────────────────┐
│ Compose - Split (on PLANNER_TASK_ID:) │
└──────────────┬────────────────────────┘
               │
               ▼
┌───────────────────────────────────────┐
│ Compose - Extract ID (clean trailing) │
└──────────────┬────────────────────────┘
               │
               ▼
┌───────────────────────────────────────┐
│ Set variable: varPlannerStoryId       │
└──────────────┬────────────────────────┘
               │
               ▼
┌───────────────────────────────────────┐
│ Condition: varPlannerStoryId not empty│
└──────┬─────────────────┬─────────────┘
       │ Yes             │ No
       ▼                 ▼
┌──────────────┐   ┌──────────┐
│ Update task  │   │ (End)    │
│ Progress =   │   └──────────┘
│ Completed    │
│ (Planner)    │
└──────────────┘
```

---

## Troubleshooting This Flow

| Symptom | Cause | Fix |
|---|---|---|
| Flow doesn't trigger | Wrong Closed State value | Verify the trigger's **Closed State** matches your process (`Closed` for Agile, `Done` for Scrum) |
| Compose - Split outputs `["NOTFOUND"]` | Wrong field path | Confirm the trigger output contains `body/fields/System_Description` (underscore, NOT dot). Check raw trigger outputs. |
| Compose - Split outputs `[""]` or 1 element | Description has no `PLANNER_TASK_ID:` marker | This work item wasn't created by Flow A. The downstream Condition will skip it cleanly. |
| `Array index '1' is outside bounds` in Compose - Extract ID | Compose - Split returned only 1 element | Same as above — no PLANNER_TASK_ID marker in description |
| Planner update fails with `BadRequest` / `Resource not found for segment 'p>'` | Extracted ID has trailing `</p>` HTML | Use the cleaned expression: `trim(first(split(trim(outputs('Compose_-_Split')[1]), ' ')))` |
| Planner task not completing | Invalid Planner task ID | Verify the extracted ID matches a real Planner task — copy from run output and check in Planner |
| Trigger doesn't re-fire on same work item | Already in closed state | Set work item back to Active, then close again |
| Poller misses items | Watermark gap | Reduce poll interval or add overlap buffer |
| "Forbidden" on Planner update | Missing permissions | Ensure connection account is a member of the M365 Group |

---

## Related Documentation

- Back: [Flow A — Planner to ADO](FLOW_A_PLANNER_TO_ADO.md)
- Parent: [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- Next: [Testing Plan](TESTING_PLAN.md)
- Issues: [Troubleshooting Guide](TROUBLESHOOTING.md)
- Sample WIQL (poller, audit): [`samples/ado-wiql/`](../samples/ado-wiql/)
- Back to: [Repository README](../README.md)
