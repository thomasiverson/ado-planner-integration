# Troubleshooting Guide — Planner ↔ Azure DevOps Integration

---

## Quick Diagnostics Checklist

When something isn't working, start here:

- [ ] Are both flows **turned on**? (Solutions → Open flow → check status)
- [ ] Are the **connections** authenticated? (Solutions → Connection References)
- [ ] Are the **environment variables** set? (Solutions → Environment Variables)
- [ ] Check **flow run history**: Power Automate → Monitor → Cloud flow activity

---

## Common Issues

### 1. Flow Does Not Trigger

**Symptoms:** No flow runs appear in the run history after creating a Planner task or updating an ADO work item.

| Possible Cause | Resolution |
|---|---|
| Flow is turned off | Open the flow and click **Turn on** |
| Wrong Group ID or Plan ID | Verify `PLANNER_GROUP_ID` and `PLANNER_PLAN_ID` match your Planner plan. Open the plan in a browser and check the URL |
| Wrong ADO org/project/type | Verify `ADO_ORG`, `ADO_PROJECT`, and `ADO_WORK_ITEM_TYPE` environment variables |
| Connection expired | Open Connection References in the solution and re-authenticate |
| Trigger throttled | Power Automate may delay triggers during high load. Wait 5–10 minutes and retry |
| Task created before flow was on | Flows only trigger for events **after** being turned on |

---

### 2. Azure DevOps Work Item Not Created (Flow A)

**Symptoms:** Flow A runs but fails at the "Create a work item" step.

| Possible Cause | Resolution |
|---|---|
| ADO connection not authorized | Re-authenticate the Azure DevOps connection reference |
| Insufficient permissions | The connection account needs **Contributor** role in the ADO project |
| Invalid work item type | Verify `ADO_WORK_ITEM_TYPE` matches an existing type in your project (e.g., `Task`, `User Story`) |
| Required fields missing | Some ADO processes require fields like Area Path or Iteration Path. Add these to the flow |
| API access disabled | In ADO → Organization Settings → Policies → verify "Third-party application access via OAuth" is enabled |

---

### 3. Planner Task Not Updated with ADO Link (Flow A)

**Symptoms:** ADO work item is created, but the Planner task description doesn't show the ADO link block.

| Possible Cause | Resolution |
|---|---|
| Planner connection expired | Re-authenticate the Planner connection reference |
| Task ID mismatch | Verify the `varPlannerTaskId` variable is correctly set from the trigger |
| Description too long | Planner has a description length limit. If the original description is very long, the update may fail |
| HTML encoding issues | ADO returns HTML; ensure description composition handles plain text correctly |

---

### 4. Planner Task Not Marked Complete (Flow B)

**Symptoms:** ADO work item moves to Done, but the Planner task remains incomplete.

| Possible Cause | Resolution |
|---|---|
| State value mismatch | Check your ADO process template: Scrum uses `Done`, Agile/CMMI uses `Closed`. Update the condition |
| Planner Task ID not found | Open the ADO work item and verify `PLANNER_TASK_ID:` exists in the description (or custom field) |
| Task ID format wrong | Ensure there are no extra spaces or line breaks around the ID |
| Planner task deleted | The task may have been deleted; the flow will fail silently |
| Wrong M365 Group membership | The connection account must be a member of the M365 Group that owns the plan |

---

### 5. Duplicate Work Items Created

**Symptoms:** Multiple ADO work items are created for the same Planner task.

| Possible Cause | Resolution |
|---|---|
| Flow triggered multiple times | Add a **condition** at the start of Flow A: check if the Planner task description already contains `ADO_WORK_ITEM_ID:` — if so, skip creation |
| Flow retried after transient failure | Power Automate may retry failed runs. The duplicate-check condition above handles this |

**Recommended fix — add to Flow A:**
```
Condition: Description does not contain "ADO_WORK_ITEM_ID:"
  If yes → proceed with work item creation
  If no → terminate (skip)
```

---

### 6. Connection Reference Errors

**Symptoms:** Errors mentioning "connection not found" or "unauthorized."

**Resolution:**
1. Go to **Solutions** → open the solution
2. Click **Connection References**
3. For the failing connection, click **Edit**
4. Select an existing connection or create a new one
5. Click **Save**
6. If creating a new connection, sign in with an account that has appropriate permissions

---

### 7. Environment Variable Not Resolved

**Symptoms:** Flow actions show literal text like `@{outputs('...')}` instead of actual values.

**Resolution:**
1. Verify the environment variable has a **Current Value** set in the target environment
2. Open **Solutions** → **Environment Variables** → set the value
3. If using expressions to read environment variables, verify the expression syntax

---

### 8. "Send an HTTP request to Azure DevOps" Fails (Flow B Poller)

**Symptoms:** The HTTP request action returns 400 or 401 errors.

| Error Code | Cause | Resolution |
|---|---|---|
| 400 Bad Request | Invalid WIQL query | Test the WIQL query directly in ADO (Boards → Queries → New → switch to WIQL mode) |
| 401 Unauthorized | Auth token expired | Re-authenticate the ADO connection |
| 403 Forbidden | Insufficient scope | Ensure the connection has access to the specified project |
| 404 Not Found | Wrong project name or API version | Verify `ADO_PROJECT` and the API version in the URI |

---

## Monitoring & Alerting

### View Flow Run History

1. Go to [make.powerapps.com](https://make.powerapps.com)
2. Navigate to **Solutions** → open the solution → click the flow
3. Click **28-day run history** to see all runs
4. Click any run to see step-by-step details

### Set Up Failure Alerts

1. Go to [flow.microsoft.com](https://flow.microsoft.com)
2. Open the flow → **...** menu → **Receive notifications of failures via email**
3. Enter the email address for alerts

### Power Platform Admin Monitoring

- **Power Platform Admin Center** → **Analytics** → **Power Automate** for org-wide flow analytics
- Use the **Center of Excellence (CoE) Starter Kit** for advanced monitoring

---

## Environment Issues

### Wrong Environment

**Symptom:** Flows don't see the right connections or data.

**Resolution:**
- Verify you are in the correct environment (check the environment picker in the top-right of make.powerapps.com)
- Flows are environment-scoped and cannot access resources in other environments

### Moving Between Environments

- **Always** use Solutions for moving flows between environments
- Export from dev (unmanaged), import to prod (managed)
- Never try to recreate flows manually in production — use the solution import process

---

## Escalation Path

If the above steps don't resolve the issue:

1. **Check Power Automate service health:** [status.office.com](https://status.office.com)
2. **Check ADO service health:** [status.dev.azure.com](https://status.dev.azure.com)
3. **Open a support ticket:** Power Platform Admin Center → Help + support
4. **Collect diagnostics:**
   - Flow run ID (from the run history URL)
   - Exact error message and action name
   - Screenshots of the failed step
   - Timestamp (UTC) of the failure

---

## Related Documentation

- Administrator setup: [Administrator Handoff Guide](ADMIN_HANDOFF.md)
- Build references: [Flow A](FLOW_A_PLANNER_TO_ADO.md) · [Flow B](FLOW_B_ADO_TO_PLANNER.md) · [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- Re-validate after fixes: [Testing Plan](TESTING_PLAN.md)
- Back to: [Repository README](../README.md)
