using './main.bicep'

param namePrefix = 'planlc'
param location = 'centralus'

param adoOrg = 'tpitest'
param adoProject = 'ADO-Planner-Integration-logicapps'
param adoWorkItemType = 'User Story'

param plannerGroupId = '8edf079f-3f09-4521-9983-17d6d13d494b'
param plannerPlanId = '8qBH2yq65kybhslSXC3xaWUAEVsZ'

param tags = {
  workload: 'planner-ado-integration-consumption'
  managedBy: 'bicep'
  environment: 'demo'
}
