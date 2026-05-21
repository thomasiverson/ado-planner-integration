# Sample WIQL Queries

Optional helper queries for the Planner ↔ Azure DevOps integration. None are required to run the integration — they exist for auditing, debugging, and the Flow B polling fallback.

Run any of these from **Azure DevOps → Boards → Queries → New query → Editor (WIQL)**, or via the [Azure DevOps REST API `wiql` endpoint](https://learn.microsoft.com/azure/devops/boards/queries/wiql-syntax).

| File | Purpose | When to use |
|---|---|---|
| [`linked-work-items.wiql`](linked-work-items.wiql) | Lists every ADO work item whose description contains the `PLANNER_TASK_ID:` marker stamped by Flow A. | Audit link integrity — verify Flow A is stamping markers correctly, or find orphaned items. Includes a commented Option B for custom-field linking. |
| [`poller-query.wiql`](poller-query.wiql) | Returns work items in the `Done` state that have changed since a watermark timestamp. | **Used by Flow B Option 2 (scheduled poller fallback) only.** Skip if you are using the event-driven trigger in Flow B Option 1. |
| [`recent-completed-items.wiql`](recent-completed-items.wiql) | Lists ADO work items moved to `Done` in the last 7 days. | Debugging and testing Flow B — quickly spot which items should have completed their linked Planner tasks. |

## Notes

- The queries assume `[System.WorkItemType] = 'Task'`. Adjust to `'User Story'` (or whichever type Flow A creates) to match your `ADO_WORK_ITEM_TYPE` environment variable.
- `@project` resolves to the current project when the query is run from within an ADO project context.
- See [`docs/FLOW_B_ADO_TO_PLANNER.md`](../../docs/FLOW_B_ADO_TO_PLANNER.md) for the polling-flow details and [`docs/TROUBLESHOOTING.md`](../../docs/TROUBLESHOOTING.md) for link-integrity diagnostics.
