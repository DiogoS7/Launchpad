# Changelog

Launchpad is delivered in releases. Each one starts with business analysis, is built on the Salesforce Platform, and is tracked as a [milestone](https://github.com/DiogoS7/Launchpad/milestones) on GitHub.

| Release | Theme | Status | Requirements |
|---|---|---|---|
| [v1.0](https://github.com/DiogoS7/Launchpad/releases/tag/v1.0) | Core app | ✅ Released | [03 · BRD](docs/03-brd.md) |
| [v1.1 · Apex managed sharing](https://github.com/DiogoS7/Launchpad/milestone/4) | Reliable plan sharing | In progress | [03 · BRD, D9](docs/03-brd.md#12-design-decisions-made-during-build) |
| [v2 · Agentforce](https://github.com/DiogoS7/Launchpad/milestone/2) | Employee onboarding agent | Planned | [04 · Agent Requirements](docs/04-agent-requirements.md) |
| [v3 · Claude](https://github.com/DiogoS7/Launchpad/milestone/3) | Claude-assisted features | Planned | To be written (05) |

## [Unreleased] · v1.1 · Apex managed sharing

Fixes the trade-off recorded in decision D5: v1.0 shared plans with Flow-created manual shares, which Salesforce deletes when a plan's owner changes.

### Changed
- Plan sharing (SH-01) now uses Apex managed sharing with a `Launchpad_Participant__c` sharing reason, so participants keep Edit access when the owner changes
- Changing a project's lead now re-shares every plan on that project with the new lead
- BRD v0.3: constraint CO-02 is now "declarative first", with decision D9 recording the one place Apex is used

### Added
- `OnboardingPlanSharing` service class, with thin triggers on Onboarding Plan and Project
- `OnboardingPlanSharingRecalc` batch, to register as the object's Apex sharing recalculation class
- `OnboardingPlanSharingTest`, covering participant, owner and project-lead changes, the recalculation batch and a 200-plan bulk insert
- Scripts to rebuild plan sharing and remove the v1.0 manual shares

### Removed
- The `Onboarding_Plan_Share_With_Participants` Flow

## [Unreleased] · v2 · Agentforce

Planned scope: an employee agent, the Launchpad Onboarding Assistant, that answers tool questions from the Tool Guides, tells new hires their next and overdue tasks and progress, and points them to the right person for everything else. It is read-only and runs in the user's context, so it sees exactly what the user sees on their plan page.

Done so far:

- Agent requirements document: objectives, scope, 13 functional requirements, topics and actions, 6 user stories and a 12-utterance acceptance test set

## [Unreleased] · v3 · Claude

Planned scope: Claude-assisted features, starting with drafting a first Role Brief from a job description for the hiring manager to review.

## [1.0] · Core app

The first release: Atlântica Consulting's onboarding process redesigned and built on Salesforce, with all business logic declarative (no Apex).

### Business analysis

- AS-IS process analysis with six pain points and baseline metrics
- TO-BE process design with roles, traceability to every pain point and target metrics
- Business Requirements Document: 25 functional requirements, 12 user stories with acceptance criteria, data model, automation, security model and 8 design decisions made during the build

### Data model

- Five custom objects: Onboarding Plan, Onboarding Task (master-detail with roll-up summaries), Onboarding Task Template, Project and Tool Guide
- Shared global value set for task categories

### Automation and data quality

- Seven record-triggered Flows: manager prep task, task generation at plan start, project handover tasks, completed-date stamping, plan sharing, and two reminders on scheduled paths
- Seven validation rules enforcing the plan lifecycle (Draft → Ready → In Progress → Completed)

### Security

- Private sharing on plans with Flow-created share records for each participant
- Three permission sets (HR, Manager, Employee) and a custom permission checked in validation rules

### Reporting

- Two custom report types, four reports and a dynamic HR dashboard

### User experience

- Mission Control and Command Centre Lightning Web Components, on Lightning Data Service and the UI API GraphQL adapter, with no Apex
- Tabbed plan page with Dynamic Forms, a Path with stage guidance, quick actions, a Launchpad home page and list views

### Delivery

- All metadata and seed data in the repository, deployable to a fresh org
- CI on GitHub Actions: metadata checks and a validation deploy against a Salesforce org
