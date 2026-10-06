---
document_id: "WEBSOCKET-STANDARD"
primary_nature: "Regra"
objective: "Definir regras reutilizáveis e verificáveis para WebSocket & Real-time."
scope: "Conexão, eventos, reconexão, segurança e ciclo de vida de recursos em tempo real."
non_objectives: "Não criar requisitos de produto, decisões arquiteturais concretas ou procedimentos fora do escopo deste standard."
owner: "Arquitetura e Qualidade"
status: "Active"
date: "2026-08-25"
version: "1.4"
keywords: "websocket, standard, standard"
related_files: "./README.md, ./keycloak-frontend-standard.md, ./api-client-standard.md"
code_references: "backend/, frontend/, infra/"
principal_statement: "As regras de WebSocket & Real-time aplicam-se somente ao escopo e aos controles declarados neste standard."
---

# WebSocket & Real-time Standard — @FrontendWeb / @UIIntegrator

> **Mandatory rules** for real-time communication in the frontend. This standard defines WebSocket connection lifecycle, authentication, reconnection, event-driven cache invalidation, notification delivery, and tenant isolation.

> **Prerequisite:** Read [`keycloak-frontend-standard.md`](./keycloak-frontend-standard.md) (token injection) and [`api-client-standard.md`](./api-client-standard.md) (React Query cache invalidation).

> **Tenant-context amendment (2026-08-22):** tenant JWT identities do not duplicate their claim
> in a header; `X-Tenant-ID` is exclusive to explicit Super Admin impersonation.

---

## 1. Dependencies

| Package | Version | Purpose |
|---|---|---|
| `@stomp/stompjs` | `^7.x` | STOMP protocol client over WebSocket |

```bash
pnpm add @stomp/stompjs
```

### Why STOMP

1. Spring Boot uses STOMP over WebSocket natively (`spring-boot-starter-websocket`).
2. STOMP provides topic-based pub/sub semantics (subscribe to `/topic/fiscal.updates`).
3. Built-in heartbeat, receipt acknowledgment, and message framing.
4. Compatible with `@Kafka-Agent` event-driven architecture — backend publishes domain events to STOMP topics.

### Rules

1. **Never** use raw `WebSocket` API directly. Always use `@stomp/stompjs`.
2. **Never** use `socket.io` — it adds an unnecessary abstraction layer over STOMP.
3. **Never** use SSE (Server-Sent Events) — STOMP is bidirectional and already integrated with Spring.

---

## 2. Architecture

```
┌─────────────┐          ┌───────────────────────┐          ┌──────────────┐
│  React App  │◄── WS ──►│  Spring WebSocket     │◄── Evt ──│   Kafka /    │
│  (STOMP)    │          │  (STOMP Broker)       │          │   Modulith   │
└─────────────┘          └───────────────────────┘          └──────────────┘
      │                          │
      │  Subscribe:              │  Backend publishes:
      │  /user/queue/notifications   Domain events to STOMP
      │  /topic/fiscal.{tenantId}    topics per tenant
      │                          │
      ▼                          ▼
  React Query               Spring @SendTo
  invalidation               or SimpMessagingTemplate
```

### Communication Patterns

| Pattern | STOMP Destination | Use Case |
|---|---|---|
| **Broadcast** (per tenant) | `/topic/fiscal.{tenantId}` | Fiscal query status changed |
| **User-specific** | `/user/queue/notifications` | Personal notifications |
| **Module events** | `/topic/{module}.{tenantId}` | Module-level updates |

### Rules

1. Topics are **always** scoped by `tenantId` — `/topic/fiscal.{tenantId}`.
2. User-specific messages use `/user/queue/` prefix (STOMP user destination).
3. Backend uses `SimpMessagingTemplate` to publish to specific topics/users.

---

## 3. WebSocket Client — Singleton

```tsx
// src/lib/websocket.ts
import { Client, type IMessage } from '@stomp/stompjs';
import { getKeycloak } from '@/lib/keycloak';
import { env } from '@/lib/env';
import { AuthError } from '@/lib/apiError';
import { useImpersonateStore } from '@/stores/useImpersonateStore';

let stompClient: Client | null = null;

export const getStompClient = (): Client => {
  if (!stompClient) {
    stompClient = new Client({
      brokerURL: env.wsBaseUrl,
      connectHeaders: {},
      debug: (msg) => {
        if (process.env.NODE_ENV === 'development') {
          console.debug('[STOMP]', msg);
        }
      },

      // Reconnect with exponential backoff
      reconnectDelay: 3000,
      heartbeatIncoming: 10000,
      heartbeatOutgoing: 10000,

      // Inject auth token before each connect
      beforeConnect: async () => {
        const keycloak = getKeycloak();
        try {
          await keycloak.updateToken(10);
        } catch {
          keycloak.login();
          return;
        }
        stompClient!.connectHeaders = {
          Authorization: `Bearer ${keycloak.token}`,
          ...getImpersonationConnectHeaders(keycloak),
        };
      },
    });
  }
  return stompClient;
};

function getImpersonationConnectHeaders(
  keycloak: ReturnType<typeof getKeycloak>,
): Record<string, string> {
  const parsed = keycloak.tokenParsed as Record<string, unknown> | undefined;
  const roles = (parsed?.realm_access as { roles?: string[] })?.roles ?? [];

  if (roles.includes('ROLE_SUPER_ADMIN')) {
    const selectedTenantId = useImpersonateStore.getState().selectedTenantId;
    return selectedTenantId ? { 'X-Tenant-ID': selectedTenantId } : {};
  }

  if (!parsed?.tenant_id) throw new AuthError('Missing tenant_id in tenant identity.');
  return {};
}

export const disconnectStomp = () => {
  if (stompClient?.active) {
    stompClient.deactivate();
  }
  stompClient = null;
};
```

### Environment Variable

```env
# .env.local
NEXT_PUBLIC_WS_BASE_URL=ws://localhost:8081/ws

# .env.production
NEXT_PUBLIC_WS_BASE_URL=wss://api.example.com/ws
```

```tsx
// Add to src/lib/env.ts
export const env = {
  // ...existing
  wsBaseUrl: process.env.NEXT_PUBLIC_WS_BASE_URL!,
} as const;
```

### Rules

1. **Singleton pattern** — one STOMP client per app. Never create multiple connections.
2. `beforeConnect` refreshes the access token (10s buffer) before every (re)connect.
3. `reconnectDelay: 3000` — auto-reconnect after 3 seconds on disconnect.
4. Heartbeats every 10 seconds to detect dead connections.
5. **Debug logs only in development.** Never log STOMP frames in production.
6. `wss://` in production (encrypted). `ws://` only in local development.

---

## 4. WebSocketProvider — React Context

```tsx
// src/providers/WebSocketProvider.tsx
'use client';

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import type { Client, IMessage } from '@stomp/stompjs';
import { getStompClient, disconnectStomp } from '@/lib/websocket';
import { useAuth } from '@/hooks/useAuth';

// ---------- Types ----------

type MessageHandler = (message: IMessage) => void;

interface WebSocketContextValue {
  isConnected: boolean;
  subscribe: (destination: string, handler: MessageHandler) => () => void;
}

// ---------- Context ----------

const WebSocketContext = createContext<WebSocketContextValue | undefined>(undefined);

// ---------- Provider ----------

export const WebSocketProvider = ({ children }: { children: ReactNode }) => {
  const { isAuthenticated, user } = useAuth();
  const [isConnected, setIsConnected] = useState(false);
  const clientRef = useRef<Client | null>(null);

  useEffect(() => {
    if (!isAuthenticated || !user) return;

    const client = getStompClient();
    clientRef.current = client;

    client.onConnect = () => {
      setIsConnected(true);
    };

    client.onDisconnect = () => {
      setIsConnected(false);
    };

    client.onStompError = (frame) => {
      console.error('[STOMP] Error:', frame.headers['message']);
      setIsConnected(false);
    };

    client.activate();

    return () => {
      disconnectStomp();
      clientRef.current = null;
      setIsConnected(false);
    };
  }, [isAuthenticated, user?.tenantId]);

  const subscribe = (destination: string, handler: MessageHandler) => {
    const client = clientRef.current;
    if (!client?.active) {
      // Queue subscription — will subscribe on connect
      const onConnect = client?.onConnect;
      if (client) {
        client.onConnect = (frame) => {
          (onConnect as (frame: unknown) => void)?.(frame);
          client.subscribe(destination, handler);
        };
      }
      return () => {};
    }

    const subscription = client.subscribe(destination, handler);
    return () => subscription.unsubscribe();
  };

  return (
    <WebSocketContext.Provider value={{ isConnected, subscribe }}>
      {children}
    </WebSocketContext.Provider>
  );
};

// ---------- Hook ----------

export const useWebSocket = () => {
  const context = useContext(WebSocketContext);
  if (!context) {
    throw new Error('useWebSocket must be used within WebSocketProvider');
  }
  return context;
};
```

### Provider Placement

```tsx
// src/providers/Providers.tsx — add WebSocketProvider
<QueryClientProvider client={queryClient}>
  <AuthProvider>
    <WebSocketProvider>
      <ThemeProvider>
        <ToastProvider>{children}</ToastProvider>
      </ThemeProvider>
    </WebSocketProvider>
  </AuthProvider>
</QueryClientProvider>
```

### Rules

1. `WebSocketProvider` sits **inside** `AuthProvider` (needs auth state) and **outside** `ThemeProvider`.
2. Connection is only activated when `isAuthenticated === true`.
3. On `user.tenantId` change (tenant switch), the WebSocket **reconnects** with new headers.
4. `subscribe()` returns an **unsubscribe function** — must be called in cleanup.

---

## 5. Event-Driven Cache Invalidation

The primary use of WebSocket is to **invalidate React Query cache** when the backend emits events:

```tsx
// src/hooks/useRealtimeFiscal.ts
'use client';

import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useWebSocket } from '@/providers/WebSocketProvider';
import { useAuth } from '@/hooks/useAuth';
import { fiscalKeys } from '@/hooks/queries/useFiscalQueries';

interface FiscalEvent {
  type: 'QUERY_COMPLETED' | 'QUERY_ERROR' | 'QUERY_CREATED';
  queryId: string;
  documento: string;
  timestamp: string;
}

export const useRealtimeFiscal = () => {
  const { subscribe, isConnected } = useWebSocket();
  const { user } = useAuth();
  const queryClient = useQueryClient();

  useEffect(() => {
    if (!isConnected || !user) return;

    const destination = `/topic/fiscal.${user.tenantId}`;

    const unsubscribe = subscribe(destination, (message) => {
      const event: FiscalEvent = JSON.parse(message.body);

      switch (event.type) {
        case 'QUERY_COMPLETED':
        case 'QUERY_ERROR':
          // Invalidate the specific query detail
          queryClient.invalidateQueries({
            queryKey: fiscalKeys.detail(event.queryId),
          });
          // Invalidate the list (status changed)
          queryClient.invalidateQueries({
            queryKey: fiscalKeys.lists(),
          });
          break;

        case 'QUERY_CREATED':
          // Invalidate the list to show the new query
          queryClient.invalidateQueries({
            queryKey: fiscalKeys.lists(),
          });
          break;
      }
    });

    return unsubscribe;
  }, [isConnected, user?.tenantId, subscribe, queryClient]);
};
```

### Usage in Page Component

```tsx
// src/components/fiscal/FiscalQueryPage.tsx
'use client';

import { useFiscalQueryList } from '@/hooks/queries/useFiscalQueries';
import { useRealtimeFiscal } from '@/hooks/useRealtimeFiscal';

export const FiscalQueryPage = () => {
  const { data, isLoading } = useFiscalQueryList();

  // Subscribe to real-time updates — auto-invalidates queries
  useRealtimeFiscal();

  return (/* ... */);
};
```

### Rules

1. Real-time hooks **invalidate** React Query cache. They **never** update state directly.
2. React Query refetches the latest data after invalidation — single source of truth.
3. Subscribe to **tenant-scoped topics** only: `/topic/{module}.{tenantId}`.
4. Event types match **domain events** from the backend (`@DomainExpert`).
5. **Never** replace React Query data with WebSocket payloads. Only invalidate.

---

## 6. Notification Channel

```tsx
// src/hooks/useRealtimeNotifications.ts
'use client';

import { useEffect } from 'react';
import { useWebSocket } from '@/providers/WebSocketProvider';
import { useNotificationStore } from '@/stores/useNotificationStore';

interface NotificationEvent {
  type: 'info' | 'success' | 'warning' | 'error';
  message: string;
  action?: { label: string; href: string };
}

export const useRealtimeNotifications = () => {
  const { subscribe, isConnected } = useWebSocket();
  const addNotification = useNotificationStore((s) => s.addNotification);

  useEffect(() => {
    if (!isConnected) return;

    const unsubscribe = subscribe('/user/queue/notifications', (message) => {
      const event: NotificationEvent = JSON.parse(message.body);
      addNotification({
        type: event.type,
        message: event.message,
      });
    });

    return unsubscribe;
  }, [isConnected, subscribe, addNotification]);
};
```

### Placement — App-Level

```tsx
// src/components/layout/AppShell.tsx
'use client';

import { useRealtimeNotifications } from '@/hooks/useRealtimeNotifications';

export const AppShell = ({ children }: { children: React.ReactNode }) => {
  useRealtimeNotifications(); // Subscribe once at app shell level

  return (/* sidebar, topbar, main */);
};
```

### Rules

1. User-specific notifications use `/user/queue/notifications` (STOMP user destination).
2. Notifications go to **Zustand store** (`useNotificationStore`) — not React Query.
3. Subscribe at `AppShell` level so notifications work on every page.

---

## 7. Connection Status Indicator

```tsx
// src/components/layout/ConnectionStatus.tsx
'use client';

import { useWebSocket } from '@/providers/WebSocketProvider';
import { Wifi, WifiOff } from 'lucide-react';

export const ConnectionStatus = () => {
  const { isConnected } = useWebSocket();

  if (isConnected) return null; // Hide when connected (normal state)

  return (
    <div
      role="status"
      aria-live="polite"
      className="fixed bottom-4 right-4 flex items-center gap-2 px-4 py-2 bg-warning/10 text-warning-dark rounded-lg shadow-md border border-warning/20"
    >
      <WifiOff className="w-4 h-4" />
      <span className="text-sm font-medium">Reconectando...</span>
    </div>
  );
};
```

### Rules

1. Show indicator **only** when disconnected. Connected is the default — no visual clutter.
2. Use `aria-live="polite"` for screen reader accessibility.
3. Place at bottom-right corner, fixed position.
4. Auto-hides when connection is restored (STOMP reconnect).

---

## 8. Tenant Isolation

### Subscription Scoping

```tsx
// ✅ CORRECT — Scoped to tenant
subscribe(`/topic/fiscal.${user.tenantId}`, handler);

// ❌ WRONG — Not tenant-scoped, receives all tenants' events
subscribe('/topic/fiscal', handler);
```

### Cleanup on Tenant Switch

```tsx
// In WebSocketProvider useEffect:
// When user.tenantId changes, the effect re-runs:
// 1. Old subscriptions are cleaned up (return () => disconnectStomp())
// 2. New connection established with new tenantId headers
// 3. Components re-subscribe to tenant-scoped topics
```

### Rules

1. **Every** topic subscription **must** include `user.tenantId`.
2. Backend **must** validate that the STOMP subscription matches the token's `tenant_id`.
3. On tenant switch, WebSocket **disconnects and reconnects** — all subscriptions are reset.
4. **Never** allow a subscription without tenant scope (security violation).

---

## 9. Logout & Cleanup

```tsx
// On logout (already handled by WebSocketProvider useEffect):
// 1. isAuthenticated → false
// 2. WebSocketProvider effect cleanup runs
// 3. disconnectStomp() called — closes WebSocket
// 4. All subscriptions automatically unsubscribed
// 5. isConnected → false
```

### Rules

1. **Automatic cleanup** — no manual intervention needed on logout.
2. `disconnectStomp()` nullifies the singleton — fresh instance on next login.
3. **Never** leave a WebSocket connection open after logout.

---

## 10. Testing

### Unit Test — Mock useWebSocket

```tsx
// src/test/helpers/mockWebSocket.ts
export const mockWebSocket = {
  isConnected: true,
  subscribe: vi.fn(() => vi.fn()), // Returns unsubscribe fn
};

vi.mock('@/providers/WebSocketProvider', () => ({
  useWebSocket: () => mockWebSocket,
}));
```

### Testing Real-time Invalidation

```tsx
it('invalidates fiscal queries when QUERY_COMPLETED event arrives', () => {
  const queryClient = new QueryClient();
  const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries');

  // Simulate the subscribe callback
  const handler = mockWebSocket.subscribe.mock.calls[0]?.[1];
  handler?.({ body: JSON.stringify({ type: 'QUERY_COMPLETED', queryId: '1' }) });

  expect(invalidateSpy).toHaveBeenCalledWith({
    queryKey: ['fiscal', 'detail', '1'],
  });
});
```

### Rules

1. **Mock** `useWebSocket` in unit tests — no real WebSocket connections.
2. Test the **handler logic** by invoking the subscribe callback directly.
3. E2E tests can test real WebSocket if Keycloak + backend are running in Docker Compose.
