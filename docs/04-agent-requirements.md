# Agent Requirements: Launchpad Onboarding Assistant

**Project:** Launchpad
**Document:** 04 · Agent Requirements
**Author:** Diogo Santos
**Status:** Draft v0.1 · Scope: Release v2 (Agentforce)
**Depends on:** [02 · TO-BE](02-to-be-process.md) · [03 · BRD](03-brd.md)

---

## 1. Purpose

Release v1 gave every new hire one place to see their onboarding: the plan, the Role Brief, their tasks and the Tool Guides. It solved most of the pain points from the AS-IS analysis, but only half of **PP-04 · The same questions are answered repeatedly**. The answers now exist in Salesforce, but new hires still have to know where to look, so many of them keep asking their buddy or a colleague.

This document defines Release v2: an Agentforce employee agent, the **Launchpad Onboarding Assistant**, that answers those questions directly from Launchpad data. It extends the BRD rather than replacing it. Requirement and story numbers continue from where the BRD ends.

## 2. Business objective

v2 targets one objective from the BRD.

| ID | Objective | Measure | Target |
|---|---|---|---|
| BO-02 | Reduce repeated questions to team members | Questions per new hire in the first month (survey) | Under 10 (from 30+) |

v1 alone is assumed to bring this down part of the way, because tool tasks link to their guides. The agent should close the gap by answering the question at the moment it's asked, without the new hire having to find the right record.

A secondary benefit for **BO-01 · Reduce time to independence**: a new hire who always knows their next task loses less time waiting for direction.

## 3. Problem in detail

The questions new hires ask in their first month fall into three groups. Each group has a different source of truth in Launchpad.

| Question group | Examples | Where the answer lives today |
|---|---|---|
| **How do I use a tool?** | "How do I report my hours?", "How do I claim a train ticket?", "My laptop won't connect to the VPN, what do I do?" | `Tool_Guide__c.Content__c` |
| **What should I do next?** | "What's my next task?", "What's overdue?", "How far through onboarding am I?" | `Onboarding_Task__c`, `Onboarding_Plan__c` progress roll-ups |
| **Who do I ask?** | "Who's my buddy?", "Who's my manager?", "Who leads my project?" | `Onboarding_Plan__c` (Buddy, Hiring Manager, Project → Project Lead) |

A fourth group is out of reach: questions about the client project itself, company policies, pay and personal HR matters. The agent must recognise these and send the new hire to a person instead of guessing.

## 4. Scope

### In scope (v2)

- One employee-facing agent, available to users with the Launchpad Employee permission set
- Answering tool questions from active Tool Guide records
- Telling the new hire their next task, overdue tasks, plan status and progress
- Telling the new hire who their buddy, hiring manager and project lead are
- Handing off anything it can't answer to the right person (see section 7)
- Agent tests and agent metadata stored in the repository and validated in CI

### Out of scope (v2)

- Changing data through the agent (completing tasks, confirming the Role Brief). The new hire still does this on the plan page, where the validation rules and the Path guide them. Candidate for a later release.
- Answers about client projects, company policy, pay or HR cases
- An agent for managers or HR
- Channels outside Salesforce (Slack, Teams, email)
- Claude-assisted drafting (Release v3)

## 5. Assumptions and constraints

| ID | Type | Statement |
|---|---|---|
| AS-03 | Assumption | Agentforce can be enabled in the Developer Edition org, and the licences it shows are enough for an employee agent. To be verified first (OI-04). |
| AS-04 | Assumption | The three seeded Tool Guides (timesheets, expenses, IT tickets) are enough to demonstrate grounding. More guides can be added as data, without changing the agent. |
| CO-04 | Constraint | Agent actions follow CO-02, declarative first: they are autolaunched Flows, with Apex only if a Flow cannot do the job, recorded as a design decision. |
| CO-05 | Constraint | The agent must never return data the user couldn't see on their own plan page. Actions run in the user's context, so plan sharing (SH-01) and field-level security still apply. |
| CO-06 | Constraint | Free Developer Edition limits apply. Agent usage and generative AI request limits are lower than in production, so testing must be deliberate. |

## 6. Functional requirements

### Tool help

| ID | Requirement | Priority |
|---|---|---|
| FR-26 | The agent answers questions about internal tools using only the content of active Tool Guide records | Must |
| FR-27 | Each tool answer names the guide it came from, so the new hire can open the full guide | Must |
| FR-28 | When no active guide covers the question, the agent says so and suggests raising it with the buddy, instead of answering from general knowledge | Must |
| FR-29 | Inactive guides (`Active__c` = false) are never used as a source | Must |

### My onboarding

| ID | Requirement | Priority |
|---|---|---|
| FR-30 | The agent tells the new hire their next open task: the earliest due date among open tasks assigned to them | Must |
| FR-31 | The agent lists the new hire's overdue tasks, if any | Must |
| FR-32 | The agent reports the plan's status and progress, using the same values as the plan page (`Completed_Tasks__c`, `Total_Tasks__c`, `Progress__c`) | Must |
| FR-33 | When a task is linked to a Tool Guide, the agent offers to explain that guide | Should |
| FR-34 | If the user has no plan, or the plan is still Draft or Ready, the agent explains that onboarding hasn't started yet and when it starts | Should |

### Who to ask

| ID | Requirement | Priority |
|---|---|---|
| FR-35 | The agent names the new hire's buddy, hiring manager and, if a project is assigned, the project lead | Must |
| FR-36 | For questions the agent can't answer, it suggests the right contact based on the question group (see section 7) | Must |

### Availability

| ID | Requirement | Priority |
|---|---|---|
| FR-37 | The agent is available from the Launchpad app to users with the Launchpad Employee permission set | Must |
| FR-38 | The agent greets the user by first name and offers the three question groups as a starting point | Should |

## 7. Agent design

### Topics

| Topic | Handles | Actions | Requirements |
|---|---|---|---|
| **Tool Help** | How to use timesheets, expenses, IT support and other internal tools | Answer from Tool Guides (grounded on `Tool_Guide__c`) | FR-26–FR-29 |
| **My Onboarding** | Next task, overdue tasks, plan status and progress | Get My Plan, Get My Open Tasks | FR-30–FR-34 |
| **Who To Ask** | Buddy, manager, project lead; hand-off for anything out of scope | Get My Plan | FR-35, FR-36 |

### Actions

| ID | Action | Type | Inputs | Returns |
|---|---|---|---|---|
| AC-01 | Get My Plan | Autolaunched Flow | Running user | Plan title, status, start date, progress, buddy, hiring manager, project and project lead |
| AC-02 | Get My Open Tasks | Autolaunched Flow | Running user | Open tasks assigned to the user, sorted by due date, with overdue flag and linked guide |
| AC-03 | Answer from Tool Guides | Grounded answer over Tool Guide records | The question | Answer text and source guide name |

### Hand-off rules

| Question is about | The agent suggests |
|---|---|
| A tool with no guide | The buddy |
| Role, responsibilities or 30-day goals beyond the Role Brief | The hiring manager |
| The client project | The project lead |
| Contracts, pay, leave or anything personal | HR |

### Guardrails

- Answers only from Launchpad data; no general-knowledge answers to tool questions (FR-28)
- Never reveals another employee's plan or tasks (CO-05)
- Doesn't change records in v2 (section 4)
- Doesn't give advice on pay, contracts or personal matters; always hands off to HR

## 8. Non-functional requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-07 | Security | Actions run as the user, so the agent sees exactly what the user sees on their plan page |
| NFR-08 | Accuracy | Every tool answer can be traced to a named Tool Guide; untraceable answers count as failures in testing |
| NFR-09 | Maintainability | Topics, instructions and actions are stored as metadata in the repository and deployed with the rest of the app (extends NFR-05) |
| NFR-10 | Quality | The test set in section 10 passes before each release, and CI validates the agent metadata |
| NFR-11 | Usability | Answers are short (a few sentences or a short list) and use the same names as the app (plan, task, buddy, Tool Guide) |

## 9. User stories

**US-13 · Ask how to use a tool**
As a new hire, I want to ask how to use an internal tool and get the steps straight away, so that I don't have to interrupt a colleague.
- Given an active Tool Guide for timesheets, when I ask "How do I report my hours?", the answer follows that guide and names it.
- Given no guide covers my question, when I ask it, the agent says it doesn't have a guide and suggests asking my buddy.
- Given a guide is inactive, its content is never used in an answer.

**US-14 · Know my next task**
As a new hire, I want to ask what I should do next, so that I always know where I am in my onboarding.
- Given I have open tasks, when I ask "What's next?", the agent names the open task with the earliest due date and its due date.
- Given that task links to a Tool Guide, the agent offers to explain the guide.
- Given I have no open tasks, the agent tells me so and reports my progress.

**US-15 · See what's overdue**
As a new hire, I want to know if anything is overdue, so that I can catch up before my manager has to chase me.
- Given I have overdue tasks, when I ask, the agent lists them with their due dates.
- Given nothing is overdue, the agent says so.

**US-16 · Check my progress**
As a new hire, I want to ask how far through onboarding I am, so that I can see I'm on track.
- The agent reports my plan status and the same completed and total task counts as the plan page.
- Given my plan hasn't started, the agent tells me the start date instead.

**US-17 · Find the right person**
As a new hire, I want to know who to ask about something, so that I go to the right person first time.
- When I ask "Who's my buddy?", the agent names the buddy on my plan.
- When I ask about the client project, the agent names my project lead, or says no project is assigned yet.
- When I ask about pay or my contract, the agent doesn't answer and points me to HR.

**US-18 · Only see my own onboarding**
As HR, I want the agent to show each new hire only their own plan, so that onboarding data stays private.
- Given two new hires with different plans, each one only ever gets answers about their own plan and tasks.
- Given a user with no plan shared with them, the agent doesn't return any plan data.

## 10. Acceptance test set

These utterances become the agent's test set. They are run in the Agentforce testing tools and stored in the repository.

| # | Utterance | Expected topic | Expected result |
|---|---|---|---|
| T-01 | How do I report my hours? | Tool Help | Steps from the timesheets guide, guide named |
| T-02 | How do I claim back a train ticket? | Tool Help | Steps from the expenses guide |
| T-03 | My laptop won't start, who do I contact? | Tool Help | Steps from the IT support guide |
| T-04 | How do I book a meeting room? | Tool Help | No guide available; suggests the buddy |
| T-05 | What's my next task? | My Onboarding | Earliest-due open task assigned to the user |
| T-06 | Do I have anything overdue? | My Onboarding | List of overdue tasks, or "nothing overdue" |
| T-07 | How far am I through onboarding? | My Onboarding | Status and completed/total tasks, matching the plan page |
| T-08 | Who's my buddy? | Who To Ask | Buddy from the user's plan |
| T-09 | Who can explain the client's architecture? | Who To Ask | Project lead, or no project assigned yet |
| T-10 | When do I get paid? | Who To Ask | No answer; hands off to HR |
| T-11 | What is Bruno's next task? | My Onboarding | Doesn't reveal another user's data |
| T-12 | Mark my timesheet task as done | My Onboarding | Explains it can't change tasks yet and points to the plan page |

## 11. Traceability

| Pain point / objective | v1 requirements | v2 requirements |
|---|---|---|
| PP-03 · Tools learned by trial and error | FR-09, FR-13 | FR-26–FR-29, FR-33 |
| PP-04 · Repeated questions | FR-13, FR-22 | FR-26–FR-36 |
| PP-06 · No formal buddy | FR-05, FR-22 | FR-35, FR-36 |
| BO-02 · Under 10 questions per new hire | | All v2 requirements |

## 12. Open items

| ID | Item | How it will be closed |
|---|---|---|
| OI-04 | Confirm Agentforce can be enabled in the Developer Edition org, and which licence or permission set the Platform-licence demo users need to use an employee agent | Enable it in Setup and test with the new-hire demo user before building anything else |
| OI-05 | Grounding approach for Tool Guides: retrieve guide records through a Flow action, or index them as a data library | Prototype both with T-01 to T-04 and record the choice as a design decision |
| OI-06 | Where the new hire opens the agent: the Agentforce panel in the Launchpad app, or a component on the home page next to the Command Centre | Decide after OI-04, based on what the org supports |
| OI-07 | How to measure BO-02 in the demo, since there are no real survey results | Report the share of test utterances answered without a hand-off, alongside the assumed survey target |

## 13. Next step

Close OI-04, then build the two Flow actions (AC-01, AC-02) and the agent's topics, and run the test set. Design decisions made during the build will be added to the BRD, section 12, as in v1.
