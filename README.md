# Planner ↔ Azure DevOps Integration

Bi-directional integration between **Microsoft Planner** and **Azure DevOps**, shipped in two complete editions. Pick the one that matches your operating model.

| Direction | Trigger | Result |
|---|---|---|
| **Planner → ADO** | New Planner task created | ADO work item created; link written back to Planner task |
| **ADO → Planner** | ADO work item state → Done/Closed | Linked Planner task marked complete |

## Choose your edition

| | [`power-automate/`](power-automate/) | [`logic-apps/`](logic-apps/) |
|---|---|---|
| **Platform** | Power Automate (Power Platform Solution) | Azure Logic Apps Standard |
| **Build artifact** | Solution `.zip` (PAC CLI) | Bicep + workflow JSON |
| **Auth model** | Connection references (Entra ID / PAT) | User-assigned managed identity (passwordless) |
| **Hosting** | Power Platform tenant | Your Azure subscription |
| **Best for** | M365-centric, citizen developers, no Azure footprint required | Engineering-owned, Azure-centric, IaC-deployable, fully passwordless |
| **Deploy method** | Import solution into target environment | `az deployment group create` + zip-deploy |
| **Latency (ADO→Planner)** | Polling (default ~5 min) | Service hook push (sub-second) |
| **Operational ownership** | Power Platform admin | Azure / DevOps engineer |

> **Not sure?** If your team already runs Power Automate flows, start with [`power-automate/`](power-automate/). If you prefer IaC, managed identity, and Azure-native operations, start with [`logic-apps/`](logic-apps/).

## Repository structure

```
├── README.md                  # This file — chooser & overview
├── LICENSE                    # MIT
├── .gitignore
├── power-automate/            # Power Automate edition (low-code)
│   ├── README.md              #   Edition entry point
│   ├── docs/                  #   7 markdown guides
│   ├── scripts/               #   PAC CLI helper scripts
│   └── samples/ado-wiql/      #   WIQL queries (audit, poller, debugging)
└── logic-apps/                # Azure Logic Apps Standard edition (IaC)
    ├── README.md              #   Edition entry point
    ├── docs/                  #   8 markdown guides
    ├── infra/                 #   Bicep templates (main + 3 modules)
    ├── workflows/             #   host.json + 2 workflow.json definitions
    └── scripts/               #   4 deployment scripts (infra → graph → workflows → hook)
```

## License

[MIT](LICENSE)
