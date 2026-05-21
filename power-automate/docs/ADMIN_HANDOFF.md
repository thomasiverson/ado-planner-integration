# Administrator Handoff Guide — Planner ↔ Azure DevOps Integration

This guide walks the administrator through importing, configuring, and validating the Planner–Azure DevOps integration solution.

---

## Prerequisites

Before you begin, ensure the following are in place:

### Licensing & Access

| Requirement | Details |
|---|---|
| **Microsoft 365** | Active subscription with Microsoft Planner access |
| **Power Automate** | Premium license (the Azure DevOps connector is a Premium connector) |
| **Azure DevOps** | Organization and Project created, API access enabled |
| **Power Platform** | Access to the target environment where the solution will be imported |
| **Permissions** | System Administrator or Environment Maker role in Power Platform |
| **Permissions** | Contributor or higher in the target Azure DevOps project |
| **Permissions** | Member of the Microsoft 365 Group that owns the Planner plan |

### Information You Will Need

Gather these values before importing:

| Variable | Description | Example |
|---|---|---|
| `ADO_ORG` | Your Azure DevOps organization name | `contoso` |
| `ADO_PROJECT` | The target ADO project name | `ProductBacklog` |
| `ADO_WORK_ITEM_TYPE` | Work item type to create | `Task` or `User Story` |
| `PLANNER_GROUP_ID` | Microsoft 365 Group ID that owns the plan | `a1b2c3d4-...` |
| `PLANNER_PLAN_ID` | The Planner Plan ID | `x9y8z7w6-...` |

> **How to find Group ID and Plan ID:** Open the Planner plan in a browser. The URL contains the Group ID and Plan ID:
> `https://tasks.office.com/.../<GroupId>/.../<PlanId>/...`
> Alternatively, use the Microsoft Graph Explorer: `GET https://graph.microsoft.com/v1.0/me/planner/plans`

---

## Step 1 — Import the Solution

> **You need a solution `.zip` to import.** This repo ships the documentation and scripts only; the solution itself is not pre-built. Have your solution engineer follow the [Implementation Guide](IMPLEMENTATION_GUIDE.md) to build and export `PlannerAdoIntegration_managed.zip`, then return here to import it.

### Option A: Import via Power Platform Admin Center (Recommended)

1. Navigate to [make.powerapps.com](https://make.powerapps.com)
2. Select the **target environment** from the environment picker (top-right)
3. Go to **Solutions** in the left navigation
4. Click **Import solution**
5. Click **Browse** and select the `PlannerAdoIntegration_managed.zip` file
6. Click **Next**
7. Review the solution details and click **Import**
8. Wait for the import to complete (this may take 1–3 minutes)

### Option B: Import via PAC CLI (Scripted)

If you prefer command-line import, see the `scripts/03-import-solution.ps1` script included in this package.

```powershell
.\scripts\03-import-solution.ps1 -SolutionZipPath ".\solution\PlannerAdoIntegration_managed.zip" -TargetEnvironment "https://your-env.crm.dynamics.com"
```

---

## Step 2 — Configure Connection References

After import, the solution's flows need active connections to Planner and Azure DevOps.

1. In **Solutions**, open the `PlannerAdoIntegration` solution
2. Click on **Connection References** in the left panel
3. For each connection reference:
   - **Planner Connection Reference** — Click **Edit**, select an existing Planner connection or create a new one, then **Save**
   - **Azure DevOps Connection Reference** — Click **Edit**, select an existing Azure DevOps connection or create a new one, then **Save**

> **Security note:** The connections run under the identity of the user who creates them. Use a service account with appropriate permissions for production deployments. Prefer Entra ID (OAuth) authentication.

---

## Step 3 — Set Environment Variables

1. In the solution, click on **Environment Variables**
2. Set each variable with your values:

| Variable | Your Value |
|---|---|
| `ADO_ORG` | *(your Azure DevOps org name)* |
| `ADO_PROJECT` | *(your ADO project name)* |
| `ADO_WORK_ITEM_TYPE` | `Task` or `User Story` |
| `PLANNER_GROUP_ID` | *(your M365 Group ID)* |
| `PLANNER_PLAN_ID` | *(your Plan ID)* |

3. Click **Save** after setting each variable

---

## Step 4 — Turn On the Flows

Both flows are imported in an **Off** state by default.

1. In the solution, locate the two cloud flows:
   - **Flow A — Planner to Azure DevOps**
   - **Flow B — Azure DevOps to Planner**
2. Click each flow name to open it
3. Click **Turn on** in the toolbar
4. Repeat for both flows

---

## Step 5 — Validate the Integration

### Test Case 1: Planner → Azure DevOps (Flow A)

1. Open your Planner plan
2. Create a new task:
   - **Title:** `TEST — Integration Validation`
   - **Description:** `This is a test task for integration validation`
3. Wait 1–2 minutes for the flow to trigger
4. **Verify in Azure DevOps:**
   - Navigate to your ADO project → Boards → Work Items
   - Confirm a new work item titled `TEST — Integration Validation` exists
   - Confirm the description matches
5. **Verify in Planner:**
   - Open the test task
   - Confirm the description now contains an ADO link block:
     ```
     ---
     Linked Azure DevOps Work Item
     ADO_WORK_ITEM_ID: <id>
     ADO_WORK_ITEM_URL: https://dev.azure.com/<org>/<project>/_workitems/edit/<id>
     ```

### Test Case 2: Azure DevOps → Planner (Flow B)

1. In Azure DevOps, open the work item created by Test Case 1
2. Change the **State** to `Done` (or `Closed`, depending on your process)
3. Save the work item
4. Wait 1–2 minutes for the flow to trigger
5. **Verify in Planner:**
   - Open the test task
   - Confirm it is now marked as **Completed**

### Cleanup

After validation, delete or mark the test task/work item as appropriate.

---

## Step 6 — Go Live

Once both test cases pass:

1. Communicate the integration to your team
2. Establish the convention: **create tasks in Planner** (business intake) and **track execution in Azure DevOps** (engineering)
3. Monitor the flows for the first week via **Power Automate → Monitor → Cloud flow activity**

---

## Support & Escalation

| Issue | First Step |
|---|---|
| Flow not triggering | Check Power Automate → Monitor → Cloud flow activity for errors |
| Connection error | Re-authenticate the connection reference |
| Wrong ADO project | Update the `ADO_PROJECT` environment variable |
| Duplicate work items | Verify the ID-link block is present in Planner task description |
| Permission denied | Verify the connection account has Contributor access to ADO project |

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Appendix: Solution Contents

| Component | Type | Description |
|---|---|---|
| Flow A — Planner to Azure DevOps | Cloud Flow | Creates ADO work item from new Planner task |
| Flow B — Azure DevOps to Planner | Cloud Flow | Completes Planner task when ADO item is Done |
| Planner Connection Reference | Connection Reference | Connection to Microsoft Planner |
| Azure DevOps Connection Reference | Connection Reference | Connection to Azure DevOps |
| ADO_ORG | Environment Variable | Azure DevOps organization name |
| ADO_PROJECT | Environment Variable | Azure DevOps project name |
| ADO_WORK_ITEM_TYPE | Environment Variable | Work item type (Task/User Story) |
| PLANNER_GROUP_ID | Environment Variable | M365 Group ID for Planner |
| PLANNER_PLAN_ID | Environment Variable | Planner Plan ID |

---

## Related Documentation

- Context: [Solution Overview](SOLUTION_OVERVIEW.md)
- Validation: [Testing Plan](TESTING_PLAN.md)
- Issues: [Troubleshooting Guide](TROUBLESHOOTING.md)
- For engineers (build details): [Implementation Guide](IMPLEMENTATION_GUIDE.md)
- Back to: [Repository README](../README.md)
