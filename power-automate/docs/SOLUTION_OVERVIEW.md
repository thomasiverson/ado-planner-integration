# Planner ↔ Azure DevOps Integration — Solution Overview

---

## The Problem

Business teams use **Microsoft Planner** to track work. Engineering teams use **Azure DevOps**. Today, keeping these two systems in sync requires manual copy-paste, leading to:

- Missed handoffs between business and engineering
- Duplicate data entry and stale status
- No single view of "what's in progress" across both teams

---

## The Solution

An automated, bi-directional bridge powered by **Power Automate** that keeps Planner and Azure DevOps in sync — no manual effort required.

---

## How It Works

```
BUSINESS SIDE                    INTEGRATION LAYER                 ENGINEERING SIDE
─────────────                    ─────────────────                 ────────────────

┌──────────────┐    ① Task Created    ┌───────────────┐   ② Create Work Item   ┌──────────────┐
│              │ ──────────────────►  │               │ ──────────────────────► │              │
│  Microsoft   │                      │    Power      │                         │  Azure       │
│  Planner     │    ④ Mark Complete   │    Automate   │   ③ State → Done       │  DevOps      │
│              │ ◄──────────────────  │               │ ◄────────────────────── │              │
└──────────────┘                      └───────────────┘                         └──────────────┘

     INTAKE                           ORCHESTRATION                           EXECUTION
  (Business users                   (Automated, no                         (Engineering
   create tasks)                     manual steps)                          tracks work)
```

---

## Two Automated Flows

### Flow A: Planner → Azure DevOps

| Step | What Happens |
|------|-------------|
| **1** | Business user creates a task in Planner |
| **2** | Power Automate detects the new task |
| **3** | A matching work item is created in Azure DevOps |
| **4** | The Planner task is updated with a link back to the ADO work item |

**Result:** Engineering immediately sees the new work in their backlog — no Slack message or email needed.

### Flow B: Azure DevOps → Planner

| Step | What Happens |
|------|-------------|
| **1** | Engineer completes work and sets the ADO item to "Done" |
| **2** | Power Automate detects the state change |
| **3** | The linked Planner task is automatically marked complete |

**Result:** Business stakeholders see real-time status without asking "is this done yet?"

---

## Key Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| **Source of truth for intake** | Planner | Business users already work here |
| **Source of truth for status** | Azure DevOps | Engineers track execution here |
| **Integration platform** | Power Automate | Native M365/ADO connectors, no custom code |
| **Packaging** | Power Platform Solution | Portable, version-controlled, ALM-ready |
| **Authentication** | Entra ID (OAuth) | Enterprise-grade, no shared passwords |

---

## What Gets Synced

```
PLANNER TASK                              ADO WORK ITEM
────────────                              ─────────────
Title           ──────────────────►       Title
Description     ──────────────────►       Description
Due Date        ──────────────────►       Target Date
Assignee        ──────────────────►       Assigned To (optional)

                ◄──────────────────
Completed ✓     ◄──── State = Done
```

Each item is **linked by ID** — the Planner task stores the ADO work item ID, and the ADO work item stores the Planner task ID. This prevents duplicates and enables reliable two-way sync.

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Microsoft 365 Tenant                         │
│                                                                     │
│   ┌─────────────┐     ┌──────────────────────┐     ┌────────────┐  │
│   │  Microsoft  │     │   Power Platform      │     │   Azure    │  │
│   │  Planner    │     │                        │     │   DevOps   │  │
│   │             │     │  ┌──────────────────┐  │     │            │  │
│   │  ┌───────┐  │     │  │  Power Automate  │  │     │  ┌──────┐ │  │
│   │  │ Tasks │◄─┼─────┼──┤                  ├──┼─────┼─►│Work  │ │  │
│   │  └───────┘  │     │  │  • Flow A        │  │     │  │Items │ │  │
│   │             │     │  │  • Flow B        │  │     │  └──────┘ │  │
│   └─────────────┘     │  └──────────────────┘  │     └────────────┘  │
│                       │                        │                     │
│                       │  ┌──────────────────┐  │                     │
│                       │  │ Environment Vars │  │                     │
│                       │  │ Connection Refs  │  │                     │
│                       │  └──────────────────┘  │                     │
│                       └──────────────────────┘  │                    │
└─────────────────────────────────────────────────────────────────────┘
                              │
                    Packaged as a Power Platform
                    Solution (.zip) for easy
                    deployment across environments
```

---

## Deployment Model

```
   DEV ENVIRONMENT                              PROD ENVIRONMENT
   ───────────────                              ────────────────

   ┌────────────────┐     Export (PAC CLI)      ┌────────────────┐
   │  Build & Test  │  ─────────────────────►   │  Import & Go   │
   │  Flows in UI   │     Solution .zip         │  Set variables │
   │                │                            │  Turn on flows │
   └────────────────┘                            └────────────────┘

   Engineer builds once                         Customer imports in minutes
```

- **No custom code** to deploy — just a solution zip file
- **Environment variables** make it portable across orgs
- **Connection references** let each environment use its own credentials

---

## Security Highlights

- **Entra ID authentication** — no shared passwords or tokens in the solution
- **Least-privilege access** — connections only need contributor-level permissions
- **No data stored** in the integration layer — Power Automate passes data through
- **Solution-packaged** — auditable, version-controlled, removable

---

## Value Summary

| Without Integration | With Integration |
|---------------------|-----------------|
| Manual copy-paste between systems | Automatic sync in real-time |
| Status updates via email/chat | Status visible in both tools instantly |
| Risk of missed handoffs | Every Planner task → ADO work item |
| "Is this done?" follow-ups | Auto-completion when engineering finishes |
| Duplicate data entry | Single point of entry, synced everywhere |

---

## Related Documentation

- Next: [Implementation Guide](IMPLEMENTATION_GUIDE.md) — build the flows
- For administrators: [Administrator Handoff Guide](ADMIN_HANDOFF.md)
- Validation: [Testing Plan](TESTING_PLAN.md)
- Issues: [Troubleshooting Guide](TROUBLESHOOTING.md)
- Back to: [Repository README](../README.md)
