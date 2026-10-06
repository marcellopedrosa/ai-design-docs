---
document_id: "DATA-GRID-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para Data Grid & List."
scope: "Paginação, filtros, estados e comportamento consistente de grades e listas."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "data, grid, standard, standard"
related_files: "./README.md, ./state-management-standard.md"
code_references: "backend/, frontend/"
principal_statement: "As regras de Data Grid & List aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# Data Grid & List Standard — @FrontendWeb

> **Mandatory rules** for building data grids, lists, and tables. This standard defines the mandatory inclusion of pagination and search filters across ALL screens displaying business entities, ensuring a consistent user experience and scalable data fetching.

> **Prerequisite:** Read [`state-management-standard.md`](./state-management-standard.md) for rules on storing pagination state in the URL (optional but recommended for deep linking) or local state.

---

## 1. Problem Statement

Some grids (like `TenantListTable`) were implemented with full search and pagination capabilities, while others (like `UsersTabContent`) were implemented as simple static lists without controls. This creates inconsistency in the UI/UX and risks performance degradation when datasets grow.

**This standard mandates that ALL data grids must follow the full paginated and searchable pattern by default.**

---

## 2. Core Constraints (The "Golden Rules")

| # | Rule | Rationale |
|---|---|---|
| 1 | **Mandatory Pagination:** Every `DataTable` implementation MUST include the `pagination` prop with `page`, `pageSize`, and `totalItems`. | Prevents UI freezing on large datasets and standardizes data fetching |
| 2 | **Search Filter:** A global text search input MUST be present directly above the grid, bound to the query state. | Allows users to locate records quickly |
| 3 | **State Reset:** Changing the search term MUST reset the `page` to `0`. | Prevents users from being stranded on an empty page 5 when a search only yields 1 result |
| 4 | **Backend Alignment:** The fetching hook (`useQuery`) MUST accept `{ page, size, search }` parameters and interact with a Paginated backend endpoint. | End-to-end performance and consistency |
| 5 | **Action Menus (3 Dots):** Row actions MUST be placed inside a `DropdownMenu` triggered by a `MoreHorizontal` (3 dots) icon button. Inside the menu, each `DropdownItem` MUST follow the pattern "Icon + Text" (e.g., `<Pencil className="mr-2 h-4 w-4" /> Editar`). | Keeps the grid clean, prevents horizontal overflow, and standardizes action discovery visually |

---

## 3. UI Implementation Pattern

Every grid component should be structured with a header row containing the search input (and action buttons), followed by the `DataTable`.

### Example Structure

```tsx
import * as React from 'react';
import { useTranslations } from 'next-intl';
import { DataTable, type Column } from '@/components/ui/DataTable';
import { Button } from '@/components/ui/Button';
import { Dropdown, DropdownTrigger, DropdownContent, DropdownItem } from '@/components/ui/Dropdown';
import { MoreHorizontal, Pencil } from 'lucide-react';

export function ExamplePaginatedGrid() {
  const t = useTranslations('example.grid');

  // 1. Local State for Pagination & Filters
  const [page, setPage] = React.useState(0);
  const [pageSize, setPageSize] = React.useState(10);
  const [search, setSearch] = React.useState('');

  // 2. Fetching Hook (must pass pagination params)
  const { data, isLoading } = useExampleList({ page, size: pageSize, search });

  // 3. Reset page to 0 when search changes
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearch(e.target.value);
    setPage(0); // <-- CRITICAL: Reset pagination on new search
  };

  const columns: Column<ExampleType>[] = [
    // ...
    {
      key: 'id',
      header: '',
      className: 'w-12 px-0 text-right',
      cell: (row) => (
        <div className="flex justify-end pr-4">
          <Dropdown>
            <DropdownTrigger asChild>
              <Button variant="ghost" size="icon">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownTrigger>
            <DropdownContent align="end" className="w-[180px]">
              <DropdownItem onSelect={() => handleEdit(row.id)}>
                <Pencil className="mr-2 h-4 w-4" /> Editar
              </DropdownItem>
            </DropdownContent>
          </Dropdown>
        </div>
      ),
    }
  ];

  return (
    <div className="space-y-4">
      {/* 4. Top Toolbar: Search + Actions */}
      <div className="flex items-center justify-between">
        <input
          type="search"
          placeholder={t('searchPlaceholder')}
          className="h-10 w-full max-w-sm rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
          value={search}
          onChange={handleSearchChange}
        />
        <Button>{t('addButton')}</Button>
      </div>

      {/* 5. DataTable with Pagination Configured */}
      <DataTable
        columns={columns}
        data={data?.content ?? []}
        rowKey="id"
        ariaLabel={t('tableAriaLabel')}
        pagination={{
          page: data?.page ?? 0,
          pageSize: data?.size ?? 10,
          totalItems: data?.totalElements ?? 0,
          onPageChange: setPage,
          onPageSizeChange: setPageSize,
        }}
        className={isLoading ? 'opacity-50 pointer-events-none' : ''}
      />
    </div>
  );
}
```

---

## 4. API & Hook Integration

To support this pattern, frontend `hooks/queries/` and `services/` MUST implement the Spring Boot `Page<T>` wrapper structure.

### Types definition

```typescript
// src/types/common.ts
export interface PaginatedResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}
```

### Hook implementation

```typescript
export function useExampleList(params: { page: number; size: number; search?: string }) {
  return useQuery({
    queryKey: ['example-list', params],
    queryFn: () => exampleService.list(params),
    keepPreviousData: true, // Recommended: prevents flashing while fetching next page
  });
}
```

---

## 5. Migration & Backlog Checklist

Whenever implementing or refactoring a grid list, ensure:

- [ ] Has a `search` input text field at the top-left area?
- [ ] Changing the search text resets the current `page` to `0`?
- [ ] `DataTable` receives the `pagination` object mapped to state?
- [ ] The backend call receives `page`, `size`, and `search`?
- [ ] The UI renders a loading state (e.g. `opacity-50` or skeleton) while navigating pages?
