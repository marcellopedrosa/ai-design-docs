---
document_id: "PROJECT-REPORTING-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Project Reporting."
scope: "Evidências, cadência e formato de relatórios de progresso do projeto."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "project, reporting, standard, standard"
related_files: "./README.md, harness/templates/TPL-00007-progress-report.md, ../../specs/TP-00001-backend-spring-modulith-task-plan.md, ../../specs/TP-00002-frontend-nextjs-task-plan.md"
code_references: "backend/, frontend/"
principal_statement: "As regras de Project Reporting aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Project Reporting Standard — Software Factory

> **Mandatory rules** for the agent responsible for generating project progress reports (@AgentOrchestrator). This document defines the operational workflow, data extraction rules, mathematical validation criteria, and output constraints that must be followed to produce accurate, reproducible, and hallucination-free progress reports.

> **Prerequisite:** Read [`TPL-00008-report.md`](../../../harness/templates/TPL-00008-report.md) (report skeleton and naming convention).

---

## 1. Purpose and Scope

This standard governs **how** the @AgentOrchestrator must collect, process, and present project progress data. It complements TPL-00007, which defines the **visual structure** (skeleton) of the report. Together, they ensure:

- **Reproducibility:** Given the same task plans, any agent produces the same report.
- **Zero hallucination:** All numbers are extracted directly from source documents, never estimated or invented.
- **Mathematical integrity:** All percentages, totals, and chart values are cross-validated before publication.

---

## 2. Source of Truth

The **only** authoritative data sources for progress reports are the Task Plan documents located in `/docs/delivery/plans/`:

| Domain   | Source File |
|----------|------------|
| Backend  | `../../specs/TP-00001-backend-spring-modulith-task-plan.md` |
| Frontend | `../../specs/TP-00002-frontend-nextjs-task-plan.md` |

> [!CAUTION]
> The agent must NEVER infer, estimate, or approximate progress data. All values must be extracted directly from the Execution Tracking Matrix tables in the source files above. If a task plan does not exist or is unreadable, the agent must report `N/A` for that domain and escalate.

---

## 3. Data Extraction Workflow

The agent must follow this exact sequence when generating a progress report:

### Step 1 — Read Task Plans

Open and parse both task plan files. Locate the **Execution Tracking Matrix** section (Section 2) in each file. This section contains tables with the status column using the following legend:

| Symbol | Meaning |
|--------|---------|
| ✅     | Done |
| 🔄     | In Progress |
| ⬜     | Pending |
| ⏸️     | Blocked |
| ❌     | Cancelled |

### Step 2 — Count Activities per Phase

For each phase within each domain (Backend/Frontend), count the activities by status:

- **Done:** Count all rows with ✅ status.
- **In Progress:** Count all rows with 🔄 status.
- **Not Started:** Count all rows with ⬜ or ⏸️ status.
- **Cancelled:** Count all rows with ❌ status (excluded from totals).

> [!IMPORTANT]
> When a task plan groups activities in ranges (e.g., `2.1.1–2.1.7 | Tenant Management Module (7 tasks)`), the agent must use the number explicitly stated in the description (e.g., "7 tasks") as the count, NOT count "1 row".

### Step 3 — Read the Summary Table

Each task plan contains a **Summary** table at the end of Section 2 with pre-calculated totals per phase. The agent must:

1. **Read** the summary table values.
2. **Cross-validate** them against the per-phase counts from Step 2.
3. If a discrepancy is found, use the per-row count from Step 2 (which is the ground truth) and note the discrepancy in the report's "Highlights and Observations" section.

### Step 4 — Calculate Percentages

Apply the following formula for each domain:

```
% Completed = (Done / (Total - Cancelled)) × 100
```

Round to the nearest integer. Do not use decimals in the report.

### Step 5 — Calculate Consolidated Totals

Sum Backend and Frontend values:

```
Total Planned   = Backend Planned + Frontend Planned
Total Completed = Backend Done    + Frontend Done
Total %         = (Total Completed / Total Planned) × 100
```

---

## 4. Chart Generation Rules

The report must include exactly **two (2) Mermaid pie charts**: one for Backend and one for Frontend. These charts provide the visual representation of Planned vs. Completed progress.

### 4.1 Backend Pie Chart

```mermaid
pie title Backend — Completed vs. Planned
    "Completed"      : {done_count}
    "In Progress"    : {in_progress_count}
    "Not Started"    : {not_started_count}
```

### 4.2 Frontend Pie Chart

```mermaid
pie title Frontend — Completed vs. Planned
    "Completed"      : {done_count}
    "In Progress"    : {in_progress_count}
    "Not Started"    : {not_started_count}
```

### Chart Validation Rules

| Rule | Description |
|------|-------------|
| **Sum check** | The sum of all slices must equal the total non-cancelled activities for that domain. |
| **No zero-only charts** | If all values are zero (e.g., domain not started), omit the chart and write "No activities recorded." |
| **Label consistency** | Always use the labels: `Completed`, `In Progress`, `Not Started`. Do not translate or rephrase. |
| **No percentages in charts** | Use absolute counts in chart values, not percentages. Mermaid auto-calculates the visual proportions. |

---

## 5. Report Composition Rules

### 5.1 Header

- **Project Title:** Extract from the `Project:` field in the task plan header.
- **Report Number:** Sequential 4-digit number. Check `/docs/delivery/reports/` for the latest existing report and increment by 1.
- **Issue Date:** Use the current date in `dd/MM/yyyy` format.

### 5.2 Executive Summary Tables

Each domain (Backend, Frontend) must have a table with one row per **Phase** (not per individual activity). The columns are:

| Column    | Rule |
|-----------|------|
| Category  | Phase name as defined in the task plan (e.g., "Phase 1 — Foundation") |
| Planned   | Total activities in that phase |
| Completed | Activities with ✅ status |
| Status    | ✅ if 100% done · 🔄 if partially done · ❌ if 0% done |

### 5.3 Highlights and Observations

- Maximum 3 bullet points per domain.
- Each bullet must be factual (referencing specific task IDs or phase names).
- Do not include opinions, predictions, or recommendations here. Save actionable items for "Next Steps".

### 5.4 Next Steps

- Maximum 5 items.
- Each item must reference a specific task ID or phase from the task plans.
- Use checkbox format: `- [ ] {action}`.

---

## 6. Output and Export Rules

### 6.1 File Naming

Follow the convention from TPL-00007:

```
{NNNN}-report-{project-slug}-{dd-MM-yyyy}.md
```

### 6.2 File Location

Save the generated `.md` file in: `/docs/delivery/reports/`

---

## 7. Validation Checklist

Before publishing the report, the agent must verify every item below:

| #  | Check | Required |
|----|-------|----------|
| 1  | All numbers extracted from task plan source files (no hallucination) | ✅ |
| 2  | Backend pie chart present with correct values summing to total | ✅ |
| 3  | Frontend pie chart present with correct values summing to total | ✅ |
| 4  | Consolidated table totals match the sum of Backend + Frontend | ✅ |
| 5  | Percentage formula applied correctly: `(Done / Total) × 100` | ✅ |
| 6  | Grouped task ranges expanded to their stated count (e.g., "7 tasks" = 7) | ✅ |
| 7  | Report number is sequential (checked against `/docs/delivery/reports/`) | ✅ |
| 8  | File naming convention followed: `{NNNN}-report-{slug}-{dd-MM-yyyy}.md` | ✅ |
| 9 | No mention of AI agents, IDEs, or internal tooling in the report body | ✅ |

Non-compliance with any item above is treated as a report defect and must be corrected before publication.

---

## 8. Anti-Patterns

The following behaviors are **strictly prohibited**:

| Anti-Pattern | Why It's Wrong |
|-------------|----------------|
| Inventing progress numbers | Produces misleading stakeholder reports |
| Using only the summary table without cross-validation | Summary tables may be stale if individual tasks were updated but the summary was not |
| Omitting a domain because it has 0% progress | The report must always show both Backend and Frontend, even if one is at 0% |
| Adding narrative paragraphs | The report must be lean — tables, charts, and bullet points only |

---

## Change Log

| Date       | Author   | Description |
|------------|----------|-------------|
| 2026-03-31 | @Human   | Initial creation of the Project Reporting Standard. |
