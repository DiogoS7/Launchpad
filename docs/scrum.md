# How Launchpad is delivered: Scrum

Launchpad is built in Scrum, adapted for a one-person team. I play both the Product Owner and the Developer, so the events are short and written down, and every sprint leaves a record in this repository.

## The setup

| | |
| --- | --- |
| **Sprint length** | 2 weeks, Tuesday to the second Monday |
| **Product Backlog** | [GitHub issues](https://github.com/DiogoS7/Launchpad/issues), ordered by priority on the [Launchpad board](https://github.com/users/DiogoS7/projects) |
| **Releases** | Milestones: [v2 · Agentforce](https://github.com/DiogoS7/Launchpad/milestone/2), [v3 · Claude](https://github.com/DiogoS7/Launchpad/milestone/3) |
| **Sprint Backlog** | Issues labelled `sprint N` |
| **Estimates** | Story points on a Fibonacci scale (`1 pt`, `2 pts`, `3 pts`, `5 pts`, `8 pts`), as relative effort, not hours |
| **Sprint records** | One file per sprint in [docs/sprints](sprints/): goal, plan, review and retrospective |

## The events

| Event | When | What happens | Output |
| --- | --- | --- | --- |
| **Sprint Planning** | First day of the sprint | Pick a sprint goal, pull the top Ready items that fit it, check the total against past velocity | Goal and plan in `docs/sprints/sprint-NN.md`; issues labelled `sprint N` |
| **Daily Scrum** | Each working day, 5 minutes | What moved, what's next, what's blocking. On a one-person team this is a glance at the board, not a meeting | Board up to date |
| **Sprint Review** | Last day | Demo what's Done against the goal, in the org. Reorder the backlog with what was learned | Review section in the sprint file |
| **Sprint Retrospective** | Right after the review | What helped, what got in the way, one improvement to try next sprint | Retro section in the sprint file |
| **Backlog Refinement** | Mid-sprint, about 30 minutes | Split large items, write acceptance criteria, estimate, so the next sprint starts with Ready work | Updated issues |

## Board columns

**Backlog** → **Ready** → **In progress** → **In review** → **Done**

An item moves to In review when it is built and waiting on its tests or a check in the org, and to Done only when it meets the Definition of Done.

## Definition of Ready

An item can enter a sprint when:

- It is written as a user story or a clear task, linked to its requirement IDs (FR, NFR, OI) in the docs.
- It has acceptance criteria as a checklist.
- It is estimated, and no larger than 8 points. Anything bigger is split first.
- Its dependencies are done or in the same sprint.

## Definition of Done

An item is Done when:

- Every acceptance criterion is ticked.
- The metadata is in `force-app` and CI passes (`sf project deploy validate`, lint, Jest).
- It works in the org as the persona it is for (HR, manager or new hire).
- The requirements and BRD reflect any decision taken along the way.
- The issue is closed by a commit or pull request that references it.

## Velocity

Velocity is the number of points finished per sprint. Planning uses the average of the last three sprints. Until there are three, the first sprints are planned at around 12 points.

| Sprint | Goal | Planned | Done |
| --- | --- | --- | --- |
| [1](sprints/sprint-01.md) | Prove Agentforce in the Developer Edition org and give the agent its data | 12 | |
