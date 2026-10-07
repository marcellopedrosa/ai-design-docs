---
document_id: "WEBDESIGNER-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para WebDesigner."
scope: "Entregáveis, decisões e handoff do trabalho de design de interfaces."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "webdesigner, standard, standard"
related_files: "./README.md, ../WebDesigner.md"
code_references: "frontend/"
principal_statement: "As regras de WebDesigner aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# WebDesigner Standard — @WebDesigner

> **Mandatory rules** that @WebDesigner must follow in every design specification. Referenced from the agent specification `../WebDesigner.md`.

---

## 1. Color Palette

### Primary & Secondary

| Token | Hex | HSL | Usage |
|---|---|---|---|
| `primary` | `#1E40AF` | `221 77% 40%` | Buttons, links, active states, sidebar active item |
| `primary-dark` | `#1E3A8A` | `221 77% 33%` | Hover states on primary elements |
| `primary-light` | `#3B82F6` | `217 91% 60%` | Focus rings, badges, light accents |
| `secondary` | `#64748B` | `215 16% 47%` | Secondary text, inactive icons, subtle borders |
| `secondary-dark` | `#475569` | `215 19% 35%` | Hover on secondary elements |

### Semantic Colors

| Token | Hex | Usage |
|---|---|---|
| `success` | `#16A34A` | Positive statuses, confirmations |
| `error` | `#DC2626` | Validation errors, destructive actions, delete buttons |
| `warning` | `#F59E0B` | Warnings, pending statuses (use dark text for contrast) |
| `info` | `#2563EB` | Informational badges, tooltips |

### Neutral Scale

| Token | Hex | Usage |
|---|---|---|
| `neutral-50` | `#F8FAFC` | Page background, card backgrounds |
| `neutral-100` | `#F1F5F9` | Sidebar background, alternate table rows |
| `neutral-200` | `#E2E8F0` | Borders, dividers, input borders |
| `neutral-300` | `#CBD5E1` | Disabled borders, placeholder text |
| `neutral-400` | `#94A3B8` | Placeholder text, muted icons |
| `neutral-500` | `#64748B` | Secondary text |
| `neutral-600` | `#475569` | Body text |
| `neutral-700` | `#334155` | Headings, strong labels |
| `neutral-800` | `#1E293B` | High-emphasis text |
| `neutral-900` | `#0F172A` | Maximum emphasis text, dark mode backgrounds |

### Surface Colors

| Token | Hex | Usage |
|---|---|---|
| `surface` | `#FFFFFF` | Card surface, modal surface |
| `surface-elevated` | `#FFFFFF` | Elevated cards with shadow |
| `background` | `#F8FAFC` | Page background |
| `overlay` | `rgba(15,23,42,0.5)` | Modal/drawer overlay |

### Dark Mode Variants

All tokens must have a `dark:` variant. Dark mode uses `neutral-900` as background, `neutral-800` as surface, and inverts text colors from the neutral scale.

---

## 2. Typography

### Font

- **Family:** Inter (Google Fonts), fallback: `system-ui, -apple-system, sans-serif`
- **Loading:** Use `next/font/google` for optimal performance.

### Type Scale

| Token | Size (px) | Size (rem) | Line Height | Weight | Usage |
|---|---|---|---|---|---|
| `text-xs` | 12 | 0.75 | 1rem (16px) | 400 | Badges, timestamps, helper text |
| `text-sm` | 14 | 0.875 | 1.25rem (20px) | 400 | Form labels, secondary text, table cells |
| `text-base` | 16 | 1 | 1.5rem (24px) | 400 | Body text, input text |
| `text-lg` | 18 | 1.125 | 1.75rem (28px) | 500 | Card titles, subheadings |
| `text-xl` | 20 | 1.25 | 1.75rem (28px) | 600 | Section headings |
| `text-2xl` | 24 | 1.5 | 2rem (32px) | 700 | Page titles |
| `text-3xl` | 30 | 1.875 | 2.25rem (36px) | 700 | Hero headings (rarely used) |

### Font Weights

| Token | Weight | Usage |
|---|---|---|
| `font-normal` | 400 | Body text, descriptions |
| `font-medium` | 500 | Labels, nav items, card titles |
| `font-semibold` | 600 | Section headings, button text |
| `font-bold` | 700 | Page titles, emphasis |

### Heading Hierarchy Rules

1. One `<h1>` per page — page title (e.g., "Escritórios").
2. `<h2>` for major sections within the page.
3. `<h3>` for card titles, panel headers.
4. Never skip heading levels.

---

## 3. Spacing & Layout Grid

### Base Unit

**4px** base unit. All spacing values must be multiples of 4.

### Spacing Scale

| Token | Value | Usage |
|---|---|---|
| `space-0.5` | 2px | Tiny gaps (icon-text in badges) |
| `space-1` | 4px | Minimal gap |
| `space-2` | 8px | Inline spacing, icon-text gap |
| `space-3` | 12px | Compact card padding |
| `space-4` | 16px | Standard padding, gap between fields |
| `space-5` | 20px | Card padding |
| `space-6` | 24px | Section spacing |
| `space-8` | 32px | Major section spacing |
| `space-10` | 40px | Page-level spacing |
| `space-12` | 48px | Large section dividers |
| `space-16` | 64px | Page margins |

### Breakpoints

| Token | Value | Target |
|---|---|---|
| `mobile` | 320px | Phones (min-width for design) |
| `sm` | 640px | Small tablets |
| `md` | 768px | Tablets |
| `lg` | 1024px | Desktops |
| `xl` | 1440px | Wide screens |

### Layout Rules

1. **Mobile-first:** Design for 320px first, enhance progressively.
2. **CSS Grid** for page-level layouts (sidebar + content area).
3. **Flexbox** for component-level alignment (card content, button groups).
4. **Max content width:** 1280px centered on wide screens.
5. **Sidebar width:** 256px expanded, 64px collapsed (icon-only).

---

## 4. Border Radius

| Token | Value | Usage |
|---|---|---|
| `rounded-none` | 0 | Sharp edges (rarely used) |
| `rounded-sm` | 4px | Small elements (badges, chips) |
| `rounded` | 6px | Inputs, selects |
| `rounded-md` | 8px | Buttons, dropdown menus |
| `rounded-lg` | 12px | Cards, panels, modals |
| `rounded-xl` | 16px | Elevated cards, featured sections |
| `rounded-full` | 9999px | Avatars, circular buttons, pills |

---

## 5. Shadows (Elevation)

| Token | CSS Value | Usage |
|---|---|---|
| `shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` | Subtle: inputs, small cards |
| `shadow` | `0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)` | Standard cards |
| `shadow-md` | `0 4px 6px rgba(0,0,0,0.1), 0 2px 4px rgba(0,0,0,0.06)` | Dropdowns, popovers |
| `shadow-lg` | `0 10px 15px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05)` | Modals, elevated panels |
| `shadow-xl` | `0 20px 25px rgba(0,0,0,0.1), 0 10px 10px rgba(0,0,0,0.04)` | Floating elements, dialogs |

---

## 6. Transitions & Animations

### Standard Durations

| Token | Duration | Usage |
|---|---|---|
| `duration-fast` | 150ms | Hover effects, color changes |
| `duration-normal` | 200ms | Tooltips, button state changes |
| `duration-slow` | 300ms | Modals, sidebars, drawers |

### Easing

- **Default:** `ease-in-out` for most transitions.
- **Enter:** `ease-out` for elements appearing.
- **Exit:** `ease-in` for elements disappearing.

### Micro-Interactions

1. **Buttons:** Scale to `0.98` on active (`transform: scale(0.98)`).
2. **Cards:** Slight shadow elevation on hover (`shadow-sm` → `shadow-md`).
3. **Sidebar collapse:** Smooth width transition `duration-slow`.
4. **Skeleton loading:** Pulse animation (`animate-pulse`).
5. **Toast notifications:** Slide in from top-right, fade out.
6. All animations must respect `prefers-reduced-motion: reduce`.

---

## 7. Component Visual Standards

### Buttons

| Variant | Background | Text | Border | Usage |
|---|---|---|---|---|
| Primary | `primary` | `white` | none | Main actions (Save, Create) |
| Secondary | `white` | `neutral-700` | `neutral-200` | Secondary actions (Cancel) |
| Destructive | `error` | `white` | none | Delete, remove actions |
| Ghost | `transparent` | `neutral-600` | none | Tertiary actions, in-table actions |
| Icon | `transparent` | `neutral-500` | none | Toolbar icons, close buttons |

- **Height:** 40px (default), 36px (sm), 48px (lg).
- **Padding:** `px-4 py-2` (default), `px-3 py-1.5` (sm), `px-6 py-3` (lg).
- **Border radius:** `rounded-md` (8px).
- **Disabled state:** `opacity-50`, `cursor-not-allowed`.
- **Loading state:** Spinner replacing text, button disabled.

### Inputs

- **Height:** 40px.
- **Padding:** `px-3 py-2`.
- **Border:** 1px `neutral-200`, on focus: 2px `primary`.
- **Border radius:** `rounded` (6px).
- **Placeholder:** `neutral-400` color.
- **Error state:** Border `error`, helper text in `error` color below field.
- **Disabled state:** `neutral-100` background, `neutral-400` text.

### Cards

- **Background:** `surface` (white).
- **Border:** 1px `neutral-200`.
- **Border radius:** `rounded-lg` (12px).
- **Padding:** 24px (desktop), 16px (mobile).
- **Shadow:** `shadow-sm` default, `shadow-md` on hover (when clickable).

### Tables

- **Header:** `neutral-100` background, `text-sm font-semibold neutral-700`.
- **Rows:** Alternate `white` / `neutral-50`. Hover: `primary/5%` tint.
- **Cell padding:** `px-4 py-3`.
- **Border:** Bottom border `neutral-200` between rows.
- **Responsive:** Horizontal scroll with sticky first column on mobile.

### Badges / Tags

- **Shape:** Pill (`rounded-full`), `px-2.5 py-0.5`.
- **Font:** `text-xs font-medium`.
- **Variants:** Solid (colored background) or outline (colored border + text).
- **Status mapping:** Use semantic colors (`success`, `error`, `warning`, `info`).

### Modals / Dialogs

- **Overlay:** `overlay` color, closes on click outside.
- **Container:** `surface` background, `rounded-xl`, `shadow-xl`, max-width 512px.
- **Header:** Title `text-lg font-semibold`, optional close button (X) top-right.
- **Footer:** Right-aligned action buttons (Cancel secondary, Confirm primary).
- **Animation:** Fade in overlay + scale in content `duration-slow`.

### Toast Notifications

- **Position:** Top-right, stacked.
- **Width:** 360px max.
- **Duration:** 5s auto-dismiss (configurable).
- **Variants:** Success (green left border), Error (red), Warning (amber), Info (blue).
- **Dismiss:** Close button (X), click to dismiss.

---

## 8. Sidebar & Navigation

Based on the Contador Fiscal reference:

- **Width:** 256px expanded, 64px collapsed (icon-only mode).
- **Background:** `neutral-100` (light gray).
- **Logo area:** Top, 64px height, centered brand icon + name.
- **Menu groups:** Uppercase label (`text-xs font-semibold neutral-400 tracking-wider`), 24px top margin between groups.
- **Menu items:** `flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm font-medium`.
  - Default: `text-neutral-600`, icon `neutral-400`.
  - Hover: `bg-neutral-200/50`, `text-neutral-800`.
  - Active: `bg-primary/10`, `text-primary`, icon `primary`. Left border or background highlight.
- **Icons:** 20px size, 1.5 stroke-width (Lucide).
- **Collapse toggle:** Bottom of sidebar, chevron icon.

### TopBar

- **Height:** 64px.
- **Background:** `surface` (white), bottom border `neutral-200`.
- **Content:** Search bar (center), notification bell (right), user avatar + dropdown (right).

---

## 9. Form Field Standards

### Layout

- **Label:** Above the input, `text-sm font-medium neutral-700`, `mb-1.5`.
- **Required indicator:** Red asterisk `*` after the label text.
- **Helper text:** Below the input, `text-xs neutral-400`.
- **Error message:** Below the input (replaces helper text), `text-xs error`.
- **Field spacing:** `gap-4` (16px) between fields vertically.

### Field Groups

- **Horizontal fields:** Use `grid grid-cols-2 gap-4` on desktop, stack on mobile.
- **Fieldset:** Use `<fieldset>` + `<legend>` for grouped fields (address, contact).

---

## 10. Masks & Validation Display

| Field | Mask Pattern | Placeholder |
|---|---|---|
| Documento | `XX.XXX.XXX/XXXX-XX` | `00.000.000/0000-00` |
| CPF | `XXX.XXX.XXX-XX` | `000.000.000-00` |
| Phone (mobile) | `(XX) XXXXX-XXXX` | `(00) 00000-0000` |
| Phone (landline) | `(XX) XXXX-XXXX` | `(00) 0000-0000` |
| CEP | `XXXXX-XXX` | `00000-000` |
| Currency (BRL) | `R$ X.XXX,XX` | `R$ 0,00` |

### Validation Display Rules

1. **Timing:** Validate on `blur` (when field loses focus). Show errors only after first interaction.
2. **Error border:** Input border changes to `error` color.
3. **Error text:** Appears below the input with an error icon (⚠) prefix.
4. **Success indicator:** Green checkmark icon on valid fields (optional, for critical fields like Documento).
5. **Real-time masking:** Characters format as the user types.

---

## 11. Filter Panels

Based on the Contador Fiscal reference:

- **Trigger:** "Filters" button (top-right, primary color, icon + text).
- **Panel type:** Side panel (right-aligned) or collapsible section.
- **Panel style:** `surface` background, `shadow-lg`, `rounded-lg`, `p-6`.
- **Filter fields:** Standard inputs with labels, stacked vertically.
- **Clear button:** "Clear Filters" link/button at bottom.
- **Apply:** Filters apply on change (no explicit Apply button) or have an explicit Apply button.

---

## 12. Icon Standards

- **Library:** Lucide Icons (open-source, consistent, lightweight).
- **Default size:** 20px (`w-5 h-5`).
- **Small size:** 16px (`w-4 h-4`) for inline icons, badges.
- **Large size:** 24px (`w-6 h-6`) for standalone icons, empty states.
- **Stroke width:** 1.5 (default), 2 for emphasis.
- **Color:** Inherits `currentColor` — controlled via text color utility.
- **Usage rules:**
  - Every icon button must have `aria-label` or visible text.
  - Decorative icons get `aria-hidden="true"`.
  - Consistent icons for common actions: Pencil (edit), Trash (delete), Plus (create), Search (search), X (close), ChevronDown (expand).

---

## 13. Data Presentation

### Empty States

- Centered illustration or icon (48px, `neutral-300`).
- Heading: `text-lg font-medium neutral-700`.
- Description: `text-sm neutral-500`.
- Call-to-action button (if applicable).

### Loading Skeletons

- Use `animate-pulse` with `neutral-200` background blocks.
- Match the layout structure of the loaded content.
- Minimum display: 300ms (avoid skeleton flash for fast loads).

### Pagination

- Position: Bottom-right of the table/list.
- Elements: Previous/Next buttons, page numbers (max 5 visible), page size selector `[10, 25, 50]`.
- Style: Ghost buttons for page numbers, active page highlighted with `primary` background.
