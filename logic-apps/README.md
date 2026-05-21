# Logic Apps Edition

Bi-directional **Microsoft Planner ↔ Azure DevOps** integration, deployed to Azure using Logic Apps Standard, Bicep, and a user-assigned managed identity.

## When to choose this edition

- You want an Azure-native solution deployed via Infrastructure as Code
- Your team owns and operates Azure subscriptions
- You need passwordless auth — managed identity, no PATs or client secrets
- Engineers (not citizen developers) own and extend the workflows

> Looking for the low-code Power Automate version instead? See [`../power-automate/`](../power-automate/).

## Quick Start

1. Read the [Architecture Overview](docs/ARCHITECTURE.md)
2. Confirm [Prerequisites](docs/PREREQUISITES.md)
3. Follow the [Deployment Guide](docs/DEPLOYMENT.md) — runs the four [scripts](scripts/) in order
4. Configure managed identity permissions via [Managed Identity Setup](docs/MANAGED_IDENTITY_SETUP.md)
5. Validate with the [Testing Plan](docs/TESTING.md)
6. Issues? See [Troubleshooting](docs/TROUBLESHOOTING.md)

## Structure

```
logic-apps/
├── README.md                                # This file
├── docs/
│   ├── ARCHITECTURE.md                      # Design decisions & diagrams
│   ├── PREREQUISITES.md                     # Azure, M365, ADO requirements
│   ├── DEPLOYMENT.md                        # End-to-end deployment walkthrough
│   ├── MANAGED_IDENTITY_SETUP.md            # Grant MI access to Graph & ADO
│   ├── WORKFLOW_A_PLANNER_TO_ADO.md         # Workflow A — design & expressions
│   ├── WORKFLOW_B_ADO_TO_PLANNER.md         # Workflow B — design & expressions
│   ├── TESTING.md                           # Validation test cases
│   └── TROUBLESHOOTING.md                   # Common issues & resolutions
├── infra/
│   ├── main.bicep                           # Resource-group-scope entry point
│   ├── main.bicepparam                      # Parameter file (edit, then deploy)
│   └── modules/                             # identity, storage, logic-app
├── workflows/
│   ├── host.json                            # Logic Apps host configuration
│   ├── connections.json                     # Service-provider connection bindings
│   ├── flow-a-planner-to-ado/workflow.json  # Workflow A definition
│   └── flow-b-ado-to-planner/workflow.json  # Workflow B definition
└── scripts/
    ├── 01-deploy-infra.ps1                  # Deploy Bicep to Azure
    ├── 02-grant-graph-permissions.ps1       # Grant MI access to Graph
    ├── 03-deploy-workflows.ps1              # Zip-deploy workflow definitions
    └── 04-configure-ado-service-hook.ps1    # Register ADO service hook for Flow B
```

## Prerequisites Summary

| Requirement | Details |
|---|---|
| **Azure subscription** | Owner or Contributor + User Access Administrator on the target resource group |
| **Azure DevOps** | Organization in the same Entra tenant as the Azure subscription |
| **Microsoft Planner** | Plan created in a Microsoft 365 Group |
| **Microsoft Graph** | Entra admin to grant `Tasks.ReadWrite.All` and `Group.Read.All` to the managed identity |
| **Local tooling** | Azure CLI, Bicep, PowerShell 7+, `Microsoft.Graph.Applications` module |

## Security

- **Preferred:** User-assigned managed identity for all outbound calls (Graph + ADO REST)
- **No secrets in code** — Bicep, workflow JSON, and scripts contain zero credentials
- **Least privilege** — only the two Graph app roles strictly required by the workflows
- **Storage** uses shared-key access (required by the Logic Apps Standard runtime today); the key is never emitted by the templates
