# Power Automate Edition

Bi-directional **Microsoft Planner ↔ Azure DevOps** integration, packaged as a Power Platform Solution.

## When to choose this edition

- You want a low-code, M365-native solution maintained in Power Automate
- Your team prefers the Power Platform ALM toolchain
- You don't need (or don't want) an Azure subscription footprint
- Citizen developers own and extend the flows

> Looking for the Azure / IaC version instead? See [`../logic-apps/`](../logic-apps/).

## Quick Start

1. Read the [Solution Overview](docs/SOLUTION_OVERVIEW.md)
2. Review [Prerequisites](docs/ADMIN_HANDOFF.md#prerequisites)
3. Build the flows using the [Implementation Guide](docs/IMPLEMENTATION_GUIDE.md), [Flow A](docs/FLOW_A_PLANNER_TO_ADO.md), and [Flow B](docs/FLOW_B_ADO_TO_PLANNER.md)
4. Validate with the [Testing Plan](docs/TESTING_PLAN.md)
5. Use the [PAC CLI scripts](scripts/) to export and import the solution
6. Hand off using the [Administrator Handoff Guide](docs/ADMIN_HANDOFF.md)

## Structure

```
power-automate/
├── README.md                         # This file
├── docs/
│   ├── SOLUTION_OVERVIEW.md          # High-level architecture & value
│   ├── IMPLEMENTATION_GUIDE.md       # End-to-end build (engineer)
│   ├── FLOW_A_PLANNER_TO_ADO.md      # Flow A step-by-step
│   ├── FLOW_B_ADO_TO_PLANNER.md      # Flow B step-by-step
│   ├── TESTING_PLAN.md               # Validation test cases
│   ├── ADMIN_HANDOFF.md              # Administrator import & config
│   └── TROUBLESHOOTING.md            # Common issues & fixes
├── scripts/
│   ├── 01-install-tools.ps1          # Install PAC CLI
│   ├── 02-export-solution.ps1        # Export from dev environment
│   ├── 03-import-solution.ps1        # Import to target environment
│   └── 04-unpack-pack.ps1            # Unpack/pack for source control
└── samples/
    └── ado-wiql/                     # WIQL queries (audit, poller, debugging)
```

## Prerequisites Summary

| Requirement | Details |
|---|---|
| **Power Automate license** | Premium (required for ADO connector) |
| **Azure DevOps** | Organization + project with API access enabled |
| **Microsoft Planner** | Plan created in a Microsoft 365 Group |
| **Power Platform environment** | Dev + target environment(s) |
| **Authentication** | Entra ID (preferred) or PAT (fallback) |

## Security

- **Preferred:** Entra ID (OAuth) with least-privilege access
- **Fallback:** Personal Access Token (PAT) — store in approved secret store only, rotate regularly
- **Never** store credentials in code, docs, or flow definitions
