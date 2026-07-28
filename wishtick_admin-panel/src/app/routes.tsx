import { lazy, Suspense, type ReactNode } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { AppShell } from '@/components/AppShell';
import { LoadingState } from '@/components/ui';
import { LoginPage } from '@/features/auth/LoginPage';
import { TotpEnrolmentPage } from '@/features/auth/TotpEnrolmentPage';
import { useAuth } from '@/features/auth/use-auth';
import type { AdminPermission } from '@/lib/api/schemas';
const DashboardPage = lazy(() =>
  import('@/features/dashboard/DashboardPage').then((m) => ({ default: m.DashboardPage })),
);
import { ForbiddenPage, NotFoundPage } from '@/features/misc/StatusPages';
const UsersListPage = lazy(() =>
  import('@/features/users/UsersListPage').then((m) => ({ default: m.UsersListPage })),
);
const UserDetailPage = lazy(() =>
  import('@/features/users/UserDetailPage').then((m) => ({ default: m.UserDetailPage })),
);
const ModerationQueuePage = lazy(() =>
  import('@/features/moderation/ModerationQueuePage').then((m) => ({ default: m.ModerationQueuePage })),
);
const ReportDetailPage = lazy(() =>
  import('@/features/moderation/ReportDetailPage').then((m) => ({ default: m.ReportDetailPage })),
);
const AnalyticsPage = lazy(() =>
  import('@/features/analytics/AnalyticsPage').then((m) => ({ default: m.AnalyticsPage })),
);
const AuditPage = lazy(() =>
  import('@/features/audit/AuditPage').then((m) => ({ default: m.AuditPage })),
);
const AdminsPage = lazy(() =>
  import('@/features/admins/AdminsPage').then((m) => ({ default: m.AdminsPage })),
);

/**
 * Gate for everything behind sign-in.
 *
 * Order matters: bootstrap → authenticate → enforce 2FA enrolment. The server
 * issues a working token before enrolment and does not restrict it, so this
 * gate is the only thing that enforces it.
 */
function RequireAuth({ children }: { children: ReactNode }) {
  const { isAuthenticated, isBootstrapping, mustEnrolTotp } = useAuth();
  const location = useLocation();

  if (isBootstrapping) {
    return (
      <div className="grid min-h-full place-items-center bg-ground">
        <LoadingState label="Restoring your session" />
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  if (mustEnrolTotp) {
    return <Navigate to="/setup-2fa" replace />;
  }

  return <>{children}</>;
}

/**
 * Route-level permission check.
 *
 * Deep-linking to a route the operator lacks renders a 403 explaining what is
 * missing — never a blank page, and never a silent redirect that makes the app
 * look broken.
 */
function RequirePermission({
  permission,
  children,
}: {
  permission: AdminPermission;
  children: ReactNode;
}) {
  const { can } = useAuth();
  if (!can(permission)) return <ForbiddenPage permission={permission} />;
  return <>{children}</>;
}

export function AppRoutes() {
  const { isAuthenticated, mustEnrolTotp } = useAuth();

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />

      <Route
        path="/setup-2fa"
        element={
          !isAuthenticated ? (
            <Navigate to="/login" replace />
          ) : !mustEnrolTotp ? (
            <Navigate to="/" replace />
          ) : (
            <TotpEnrolmentPage />
          )
        }
      />

      <Route
        element={
          <RequireAuth>
            <Suspense fallback={<LoadingState />}>
              <AppShell />
            </Suspense>
          </RequireAuth>
        }
      >
        <Route index element={<DashboardPage />} />

        <Route
          path="users"
          element={
            <RequirePermission permission="users:view">
              <UsersListPage />
            </RequirePermission>
          }
        />
        <Route
          path="users/:id"
          element={
            <RequirePermission permission="users:view">
              <UserDetailPage />
            </RequirePermission>
          }
        />
        <Route
          path="moderation"
          element={
            <RequirePermission permission="moderation:view">
              <ModerationQueuePage />
            </RequirePermission>
          }
        />
        <Route
          path="moderation/:id"
          element={
            <RequirePermission permission="moderation:view">
              <ReportDetailPage />
            </RequirePermission>
          }
        />
        <Route
          path="analytics"
          element={
            <RequirePermission permission="analytics:view">
              <AnalyticsPage />
            </RequirePermission>
          }
        />
        <Route
          path="audit"
          element={
            <RequirePermission permission="audit:view">
              <AuditPage />
            </RequirePermission>
          }
        />
        <Route
          path="admins"
          element={
            <RequirePermission permission="admins:manage">
              <AdminsPage />
            </RequirePermission>
          }
        />

        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  );
}
