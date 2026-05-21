using './main.bicep'

// Edit the values below before deploying.

param namePrefix = 'plannerado'
param location = 'eastus'

param adoOrg = 'contoso'
param adoProject = 'ProductBacklog'
param adoWorkItemType = 'Task'

param plannerGroupId = '00000000-1111-2222-3333-444444444444'
param plannerPlanId = 'AAAAAAAAAAAAAAAAAAAAAAA'

param enableAppInsights = true

param tags = {
  workload: 'planner-ado-integration'
  managedBy: 'bicep'
  environment: 'dev'
}
