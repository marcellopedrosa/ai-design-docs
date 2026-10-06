---
document_id: "UI-UX-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para UI/UX."
scope: "Consistência visual, interação, feedback, responsividade e experiência do usuário."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "ui, ux, standard, standard"
related_files: "./README.md, ./component-design-standard.md, ./webdesigner-standard.md"
code_references: "frontend/"
principal_statement: "As regras de UI/UX aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# UI/UX Standardization and Behavior Guide — Software Factory

> **Mandatory rules** for all agents involved in frontend implementation (@FrontendWeb, @WebDesigner, @UIIntegrator). This document defines the visual and behavioral standards for interface development, serving as a source of truth for developers and AI agents to ensure consistency across all system modules.

> **Prerequisite:** Read [`component-design-standard.md`](./component-design-standard.md) (CVA variants, compound components) and [`webdesigner-standard.md`](./webdesigner-standard.md) (design tokens, colors, typography).

---

## 1. Buttons and Actions

### Positioning and Hierarchy

* **Alignment:** In form footers, modals, or cards, the primary action button must always be positioned at the far right.
* **Reading Order (Right to Left):**
    1. Primary Action (Far right) — e.g., Save, Confirm, Submit.
    2. Secondary Action — e.g., Cancel, Back.
    3. Auxiliary Actions — e.g., Clear Filters, Reset.
* **Destructive Actions:** Buttons such as "Delete" or "Remove" should be positioned at the far left of the container to prevent accidental clicks.

### Suggested Tailwind CSS Classes

* **Primary:** `bg-blue-600 text-white hover:bg-blue-700 px-4 py-2 rounded-md transition-colors`
* **Secondary:** `border border-gray-300 text-gray-700 hover:bg-gray-50 px-4 py-2 rounded-md`
* **Destructive:** `text-red-600 hover:text-red-700 font-medium`

### Rules

1. Every form, modal, and card footer must use `flex justify-end gap-3` for button alignment.
2. The primary action button is **always** the rightmost element.
3. Destructive buttons must be visually separated from confirm/cancel buttons (e.g., positioned at the far left with `mr-auto`).
4. Loading states on submit buttons must include a `disabled` state and a spinner icon (see `component-design-standard.md` — Button `isLoading` prop).
5. **Icon Actions:** When an action is represented by an Icon (e.g., in data tables, lists, or compact cards), do **not** include descriptive text inside the button. Use the icon alone (`size="icon"`) and provide the descriptive text via a standard `Tooltip`.

---

## 2. Alert System (Feedback Messages)

Messages must be clear, actionable, and visually distinct using semantic colors and icons.

### Style and Icon Table (Tailwind + Heroicons/Lucide)

| Type        | Icon Name                | Tailwind (Icon/Text) | Tailwind (Background/Border)    | Behavior         |
| :---------- | :----------------------- | :------------------- | :------------------------------ | :---------------- |
| **Success** | `CheckCircleIcon`        | `text-green-600`     | `bg-green-50 border-green-200`  | Auto-dismiss (5s) |
| **Error**   | `XCircleIcon`            | `text-red-600`       | `bg-red-50 border-red-200`      | Manual (Close X)  |
| **Warning** | `ExclamationTriangleIcon`| `text-amber-600`     | `bg-amber-50 border-amber-200`  | Manual            |
| **Info**    | `InformationCircleIcon`  | `text-blue-600`      | `bg-blue-50 border-blue-200`    | Auto/Manual       |

### Placement Rules

1. **Global (Toasts):** Positioned in the top-right corner. Used for success messages after a screen is closed or a background action is completed.
2. **Inline (Forms):** Located at the top of the form container, immediately below the section title. Essential for displaying multiple validation errors.
3. **Field Level:** Small text (`text-xs`) placed directly below the affected input, using the `text-red-600` class.

### Rules

1. Success alerts auto-dismiss after 5 seconds. Error alerts require manual dismissal.
2. Warning alerts must persist until the user acknowledges or resolves the condition.
3. Alert components must use `role="alert"` for error/warning, and `role="status"` with `aria-live="polite"` for success/info.
4. Icons are mandatory in every alert to reinforce semantics beyond color alone (accessibility requirement).

---

## 3. Modals and Dialogs

* **Message Scoping:** If an action is triggered inside a modal, the resulting alert (success or error) must appear **inside that modal**, never on the background screen.
* **Error Persistence:** Modals must **not** close automatically if a processing error occurs.
* **Post-Modal Success:** If an action successfully closes the modal, the feedback should be displayed as a global Toast on the parent screen.
* **Standard Structure:**
    * **Header:** Clear title + "X" close button in the top right.
    * **Body:** Content with standard padding (min 24px).
    * **Footer:** Right-aligned buttons following the Primary/Secondary hierarchy (see Section 1).

### Rules

1. Modal overlays must close when clicking outside the modal **only** for non-critical actions (e.g., read-only details). Destructive or form modals must not close on outside click.
2. The Escape key must always close the modal and restore focus to the trigger element.
3. Focus must be trapped inside the modal while it is open (see `a11y-standard.md`).
4. Confirmation modals for destructive actions must use the `ConfirmDialog` shared component with `variant="destructive"`.

---

## 4. Inputs and Placeholders

* **Labels:** Must always be visible and positioned above the input field.
* **Placeholders:** Must serve as examples of real data, preceded by "e.g., ".
    * *Example:* `e.g., john.doe@company.com` or `e.g., +1 (555) 000-0000`.
* **Error States:** When validation fails, the input field must receive the `border-red-500` and `ring-red-500` classes for immediate visual feedback.

### Rules

1. Placeholders must **never** replace labels. Both must be visible simultaneously.
2. Placeholder text must be realistic and match the expected format of the field (use the mask format from `webdesigner-standard.md` Section 10 when applicable).
3. Required fields must display a red asterisk `*` after the label text.
4. Error messages appear below the input using `text-xs text-red-600` and replace any helper/hint text.
5. Validation timing: validate on `blur` (when field loses focus). Show errors only after first interaction.

---

## 5. Guidelines for AI Agents (System Instructions)

When generating components or pages, the AI agent **must** validate the following checklist:

| #  | Check                                                                                              | Required |
|----|------------------------------------------------------------------------------------------------------|----------|
| 1  | Is the primary action button on the far right? (`justify-end`)                                       | ✅       |
| 2  | Are destructive buttons separated from confirm/cancel? (far left with `mr-auto`)                     | ✅       |
| 3  | Does the alert use the correct icon and color for its severity level?                                | ✅       |
| 4  | Is there enough contrast between the alert text and background? (`bg-xx-50` with `text-xx-600`)      | ✅       |
| 5  | Do submit buttons include a `disabled` state and spinner during async operations?                    | ✅       |
| 6  | Do modals scope their alerts internally (no leaking to parent screen)?                               | ✅       |
| 7  | Do modals persist on error (no auto-close on failure)?                                               | ✅       |
| 8  | Post-modal success feedback displayed as a Toast on the parent screen?                               | ✅       |
| 9  | Do all inputs have visible labels above the field?                                                   | ✅       |
| 10 | Do placeholders use the `e.g., ` prefix with realistic data?                                         | ✅       |
| 11 | Do error states apply `border-red-500` + `ring-red-500` to the input?                                | ✅       |
| 12 | Are required fields marked with a red asterisk `*`?                                                  | ✅       |
| 13 | Do Icon-only action buttons use a Tooltip and omit internal descriptive text?                        | ✅       |

Non-compliance with any item above is treated as an implementation defect and must be corrected before handoff.

---

## Change Log

| Date       | Author       | Description                              |
|------------|--------------|------------------------------------------|
| 2026-03-25 | @Human       | Initial creation of the UI/UX standard.  |
