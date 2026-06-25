import { lazy, Suspense, type ReactNode } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './contexts/AuthContext'
import { LoadingOverlay, Box } from '@mantine/core'
import { DataMappingProvider } from './contexts/DataMappingContext'

// Layouts
import { AdminLayout } from './layouts/AdminLayout'

// Pages
const LoginPage = lazy(() => import('./pages/LoginPage').then((module) => ({ default: module.LoginPage })))
const ResetPasswordPage = lazy(() => import('./pages/ResetPasswordPage').then((module) => ({ default: module.ResetPasswordPage })))
const DashboardPage = lazy(() => import('./pages/DashboardPage').then((module) => ({ default: module.DashboardPage })))
const PasalListPage = lazy(() => import('./pages/pasal/PasalListPage').then((module) => ({ default: module.PasalListPage })))
const PasalCreatePage = lazy(() => import('./pages/pasal/PasalCreatePage').then((module) => ({ default: module.PasalCreatePage })))
const PasalEditPage = lazy(() => import('./pages/pasal/PasalEditPage').then((module) => ({ default: module.PasalEditPage })))
const PasalTrashPage = lazy(() => import('./pages/pasal/PasalTrashPage').then((module) => ({ default: module.PasalTrashPage })))
const PasalDetailPage = lazy(() => import('./pages/pasal/PasalDetailPage').then((module) => ({ default: module.PasalDetailPage })))
const UndangUndangListPage = lazy(() => import('./pages/undang-undang/UndangUndangListPage').then((module) => ({ default: module.UndangUndangListPage })))
const BulkImportPage = lazy(() => import('./pages/BulkImportPage').then((module) => ({ default: module.BulkImportPage })))
const AuditLogPage = lazy(() => import('./pages/AuditLogPage').then((module) => ({ default: module.AuditLogPage })))
const AuditLogDetailPage = lazy(() => import('./pages/AuditLogDetailPage').then((module) => ({ default: module.AuditLogDetailPage })))
const NotFoundPage = lazy(() => import('./pages/NotFoundPage').then((module) => ({ default: module.NotFoundPage })))
const ManageAdminPage = lazy(() => import('./pages/ManageAdminPage').then((module) => ({ default: module.ManageAdminPage })))
const ManageUsersPage = lazy(() => import('./pages/ManageUsersPage').then((module) => ({ default: module.ManageUsersPage })))

function PageLoader() {
  return (
    <Box pos="relative" h="60vh">
      <LoadingOverlay visible={true} />
    </Box>
  )
}

function WithDataMapping({ children }: { children: ReactNode }) {
  return <DataMappingProvider>{children}</DataMappingProvider>
}

// Protected Route wrapper
function ProtectedRoute({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <Box pos="relative" h="100vh">
        <LoadingOverlay visible={true} />
      </Box>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}

function App() {
  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        {/* Public Routes */}
        <Route path="/login" element={<LoginPage />} />
        <Route path="/reset-password" element={<ResetPasswordPage />} />

        {/* Protected Routes */}
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <AdminLayout />
            </ProtectedRoute>
          }
        >
          <Route index element={<DashboardPage />} />
          <Route path="pasal" element={<PasalListPage />} />
          <Route path="pasal/create" element={<PasalCreatePage />} />
          <Route path="pasal/:id" element={<PasalDetailPage />} />
          <Route path="pasal/trash" element={<PasalTrashPage />} />
          <Route path="pasal/:id/edit" element={<PasalEditPage />} />
          <Route path="undang-undang" element={<UndangUndangListPage />} />
          <Route path="bulk-import" element={<BulkImportPage />} />
          <Route path="audit-log" element={<WithDataMapping><AuditLogPage /></WithDataMapping>} />
          <Route path="audit-log/:id" element={<WithDataMapping><AuditLogDetailPage /></WithDataMapping>} />
          <Route path="manage-admin" element={<ManageAdminPage />} />
          <Route path="manage-users" element={<ManageUsersPage />} />
        </Route>

        {/* Catch all - 404 */}
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </Suspense>
  )
}

export default App
