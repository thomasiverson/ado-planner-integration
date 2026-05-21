# Testing Plan — Planner ↔ Azure DevOps Integration

---

## Test Environment Prerequisites

Before testing, confirm:

- [ ] Both flows are **turned on** in the target environment
- [ ] Connection references are **authenticated** and active
- [ ] Environment variables are **set** with valid values
- [ ] You have access to both the Planner plan and the ADO project
- [ ] You can create tasks in Planner and work items in ADO

---

## Test Case 1: Flow A — Planner Task Creates ADO Work Item

### Objective
Verify that creating a new Planner task triggers Flow A and creates a corresponding Azure DevOps work item with a bi-directional link.

### Steps

| Step | Action | Expected Result |
|---|---|---|
| 1 | Open the Planner plan configured in `PLANNER_PLAN_ID` | Plan opens successfully |
| 2 | Create a new task with **Title:** `TEST-001 — Integration Validation` | Task appears in Planner |
| 3 | Add **Description:** `Test task for validating Planner-ADO integration` | Description saved |
| 4 | Wait 1–3 minutes for Flow A to trigger | — |
| 5 | Open Power Automate → Monitor → Cloud flow activity | Flow A run appears with status **Succeeded** |
| 6 | In Azure DevOps, navigate to Boards → Work Items | A new work item titled `TEST-001 — Integration Validation` exists |
| 7 | Open the ADO work item | Description contains the original text AND `PLANNER_TASK_ID: <task-id>` |
| 8 | Return to Planner and open the test task | Description now contains the ADO link block (see below) |

### Expected ADO Link Block in Planner Task

```
Test task for validating Planner-ADO integration

---
Linked Azure DevOps Work Item
ADO_WORK_ITEM_ID: <number>
ADO_WORK_ITEM_URL: https://dev.azure.com/<org>/<project>/_workitems/edit/<number>
```

### Pass Criteria
- [ ] ADO work item created with correct title
- [ ] ADO work item description contains `PLANNER_TASK_ID`
- [ ] Planner task description contains `ADO_WORK_ITEM_ID` and `ADO_WORK_ITEM_URL`
- [ ] ADO link URL is clickable and opens the correct work item

---

## Test Case 2: Flow B — ADO Done State Completes Planner Task

### Objective
Verify that changing an ADO work item state to Done triggers Flow B and marks the linked Planner task as complete.

### Prerequisites
- Test Case 1 must have passed (you need a linked work item/task pair)

### Steps

| Step | Action | Expected Result |
|---|---|---|
| 1 | In Azure DevOps, open the work item created in Test Case 1 | Work item opens |
| 2 | Change the **State** to `Done` (or `Closed`, per your process) | State saved |
| 3 | Wait 1–3 minutes for Flow B to trigger | — |
| 4 | Open Power Automate → Monitor → Cloud flow activity | Flow B run appears with status **Succeeded** |
| 5 | Open the Planner plan and find the test task | Task shows as **Completed** (green checkmark / strikethrough) |

### Pass Criteria
- [ ] Flow B triggered successfully
- [ ] Planner task Progress is now **Completed**
- [ ] Task appears in Planner's "Completed" view

---

## Test Case 3: Duplicate Prevention (Flow A)

### Objective
Verify that Flow A does not create duplicate ADO work items for a task that already has a link.

### Steps

| Step | Action | Expected Result |
|---|---|---|
| 1 | Open the Planner task from Test Case 1 (already has ADO link) | Task opens, description contains ADO link block |
| 2 | Edit the task title slightly (e.g., append ` - updated`) | Title saved (this may or may not re-trigger the flow depending on trigger type) |
| 3 | Wait 3 minutes | — |
| 4 | In Azure DevOps, search for work items with "TEST-001" | Only **one** work item exists |

### Pass Criteria
- [ ] No duplicate work item created
- [ ] If Flow A re-triggered, it detected the existing link and skipped creation

> **Note:** If your flow does not yet have duplicate prevention, this test case will document the need for the guard condition.

---

## Test Case 4: Missing Link Handling (Flow B)

### Objective
Verify that Flow B handles ADO work items without a linked Planner task gracefully (no errors, no false updates).

### Steps

| Step | Action | Expected Result |
|---|---|---|
| 1 | In Azure DevOps, create a new work item **without** a `PLANNER_TASK_ID` in the description | Work item created |
| 2 | Change the State to `Done` | State saved |
| 3 | Wait 1–3 minutes | — |
| 4 | Check Power Automate → Cloud flow activity | Flow B run appears |
| 5 | Open the flow run details | Flow completed without error; the "Planner Task ID present?" condition evaluated to **No** and the flow ended gracefully |

### Pass Criteria
- [ ] Flow B did not error out
- [ ] No Planner tasks were falsely completed
- [ ] Flow run status is **Succeeded** (not Failed)

---

## Test Case 5: Connection Failure Recovery

### Objective
Verify that flows handle connection failures gracefully and can recover.

### Steps

| Step | Action | Expected Result |
|---|---|---|
| 1 | In Power Automate, temporarily remove the ADO connection from the connection reference | Connection unlinked |
| 2 | Create a new Planner task | Task created |
| 3 | Wait 1–3 minutes | — |
| 4 | Check Power Automate → Cloud flow activity | Flow A run appears with status **Failed** |
| 5 | Open the failed run | Error message indicates connection issue |
| 6 | Re-add the ADO connection to the connection reference | Connection restored |
| 7 | Create another new Planner task | Task created |
| 8 | Wait 1–3 minutes | Flow A succeeds for the new task |

### Pass Criteria
- [ ] Flow failed with a clear error message (not a cryptic error)
- [ ] After restoring the connection, new tasks are processed normally
- [ ] If failure notifications are configured, an alert was sent

---

## Test Case 6: Field Mapping Accuracy

### Objective
Verify all mapped fields transfer correctly between systems.

### Steps

| Step | Action | Expected Result |
|---|---|---|
| 1 | Create a Planner task with: Title, Description, Due Date, Assignee | Task created with all fields |
| 2 | Wait for Flow A to complete | ADO work item created |
| 3 | Open the ADO work item | Verify each field mapped correctly (see table below) |

### Field Verification

| Planner Field | Expected in ADO | Verified? |
|---|---|---|
| Title | `System.Title` matches | [ ] |
| Description | `System.Description` contains original text | [ ] |
| Due Date | `TargetDate` matches (if mapped) | [ ] |
| Assignee | `AssignedTo` matches (if mapped) | [ ] |

### Pass Criteria
- [ ] All configured field mappings are accurate

---

## Test Results Summary

| Test Case | Status | Date | Tester | Notes |
|---|---|---|---|---|
| TC1: Planner → ADO | ☐ Pass / ☐ Fail | | | |
| TC2: ADO → Planner | ☐ Pass / ☐ Fail | | | |
| TC3: Duplicate Prevention | ☐ Pass / ☐ Fail | | | |
| TC4: Missing Link | ☐ Pass / ☐ Fail | | | |
| TC5: Connection Recovery | ☐ Pass / ☐ Fail | | | |
| TC6: Field Mapping | ☐ Pass / ☐ Fail | | | |

**Overall Result:** ☐ Pass / ☐ Fail

**Sign-off:** _____________________________ Date: __________

---

## Related Documentation

- Build context: [Implementation Guide](IMPLEMENTATION_GUIDE.md) · [Flow A](FLOW_A_PLANNER_TO_ADO.md) · [Flow B](FLOW_B_ADO_TO_PLANNER.md)
- After validation: [Administrator Handoff Guide](ADMIN_HANDOFF.md)
- Issues: [Troubleshooting Guide](TROUBLESHOOTING.md)
- Sample WIQL queries: [`samples/ado-wiql/`](../samples/ado-wiql/)
- Back to: [Repository README](../README.md)
