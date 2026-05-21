# Testing — Logic Apps Edition

Validates that both workflows function end-to-end after deployment.

---

## Audience

The engineer or QA validating the deployment.

---

## Prerequisites

- [ ] All 4 deployment phases complete (see [Deployment Guide](DEPLOYMENT.md))
- [ ] Managed identity has Graph + ADO permissions (see [Managed Identity Setup](MANAGED_IDENTITY_SETUP.md))
- [ ] You have access to the Planner plan and the ADO project
- [ ] You can view Logic App run history in the Azure portal

---

## Test Case 1 — Workflow A — Planner task creates ADO work item

### Steps

| # | Action | Expected result |
|---|---|---|
| 1 | Open the Planner plan | Plan opens |
| 2 | Create a new task: **Title** = `TEST-LA-001 — Integration Validation` | Task appears |
| 3 | Add **Description**: `Logic Apps integration test` | Saved |
| 4 | Wait up to 6 minutes (next recurrence + run time) | — |
| 5 | Azure portal → Logic App → **Workflows** → `flow-a-planner-to-ado` → **Run history** | Most recent run = **Succeeded** |
| 6 | Open the run → expand each action | All actions green; HTTP POST to ADO returned `200`/`201` |
| 7 | Open the Planner task again | Description now ends with: <br>`---`<br>`ADO_WORK_ITEM_ID: <id>`<br>`ADO_WORK_ITEM_URL: https://dev.azure.com/.../_workitems/edit/<id>` |
| 8 | Click the URL | ADO work item opens; title and description match; description contains `PLANNER_TASK_ID: <task-id>` |

### Pass criteria

- ADO work item exists with the correct title and `PLANNER_TASK_ID:` marker
- Planner task description contains the `ADO_WORK_ITEM_ID:` link block
- No errors in the Logic App run history

---

## Test Case 2 — Workflow B — ADO work item closed completes Planner task

### Steps

| # | Action | Expected result |
|---|---|---|
| 1 | Open the ADO work item created by TC1 | Opens |
| 2 | Change **State** = `Done` (or `Closed`) | State updated |
| 3 | Save | ADO service hook fires |
| 4 | Azure portal → Logic App → `flow-b-ado-to-planner` → **Run history** | New run appears within seconds |
| 5 | Run status | **Succeeded** |
| 6 | Run → expand actions | State condition = true; Graph PATCH = `204 No Content` |
| 7 | Open the Planner task | Marked **Completed** (checkmark visible) |

### Pass criteria

- Planner task is marked complete within 30 seconds of the ADO state change
- No errors in the Logic App run history

---

## Test Case 3 — Idempotency (Workflow A)

### Steps

| # | Action | Expected result |
|---|---|---|
| 1 | Trigger Workflow A manually: Azure portal → workflow → **Run** | Succeeds |
| 2 | Run again immediately | Succeeds |
| 3 | Verify in ADO — no duplicate work items for the TC1 Planner task | Only one work item exists |

### Pass criteria

- The skip-if-marker-exists logic prevents duplicates across overlapping runs.

---

## Test Case 4 — Idempotency (Workflow B)

### Steps

| # | Action | Expected result |
|---|---|---|
| 1 | In ADO, set the TC1 work item back to **Active** | — |
| 2 | Set it to **Done** again | Service hook fires |
| 3 | Set it to **Active**, then **Done** a third time | Service hook fires |
| 4 | Verify in Planner — task is still Completed (or re-completed, no errors) | Workflow B runs succeed |

### Pass criteria

- Multiple closures of the same work item are handled without error.

---

## Test Case 5 — Negative case (work item without marker)

### Steps

| # | Action | Expected result |
|---|---|---|
| 1 | In ADO, create a new work item manually (not via Flow A) | — |
| 2 | Set state to `Done` | Service hook fires |
| 3 | Check Workflow B run history | Run = **Succeeded** with the "PLANNER_TASK_ID marker not found → terminate" path taken |

### Pass criteria

- No error; workflow exits cleanly when the work item didn't originate from Planner.

---

## Test Case 6 — Auth failure detection

### Steps

| # | Action | Expected result |
|---|---|---|
| 1 | Temporarily remove the MI from the ADO project's **Contributors** group | — |
| 2 | Create a Planner task → wait for Workflow A | Run **fails** with `403 Forbidden` from ADO |
| 3 | Re-add the MI to **Contributors** | — |
| 4 | Resubmit the failed run from the portal | Succeeds |

### Pass criteria

- Failures surface clearly in run history with the ADO API error message.

---

## Sign-off

| Test Case | Status | Date | Tester | Notes |
|---|---|---|---|---|
| TC1: Planner → ADO | ☐ Pass / ☐ Fail | | | |
| TC2: ADO → Planner | ☐ Pass / ☐ Fail | | | |
| TC3: Workflow A idempotency | ☐ Pass / ☐ Fail | | | |
| TC4: Workflow B idempotency | ☐ Pass / ☐ Fail | | | |
| TC5: Non-Planner work item | ☐ Pass / ☐ Fail | | | |
| TC6: Auth failure recovery | ☐ Pass / ☐ Fail | | | |

**Overall result:** ☐ Pass / ☐ Fail  **Sign-off:** _____________________________ Date: __________

---

## Related Documentation

- Deploy first: [Deployment Guide](DEPLOYMENT.md)
- Workflow internals: [Workflow A](WORKFLOW_A_PLANNER_TO_ADO.md) · [Workflow B](WORKFLOW_B_ADO_TO_PLANNER.md)
- Failure diagnosis: [Troubleshooting](TROUBLESHOOTING.md)
- Back to: [Logic Apps README](../README.md) · [Repository README](../../README.md)
