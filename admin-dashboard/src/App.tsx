import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './contexts/AuthContext'
import { LoadingOverlay, Box } from '@mantine/core'

// Layouts
import { AdminLayout } from './layouts/AdminLayout'

// Pages
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { PasalListPage } from './pages/pasal/PasalListPage'
import { PasalCreatePage } from './pages/pasal/PasalCreatePage'
import { PasalEditPage } from './pages/pasal/PasalEditPage'
import { PasalTrashPage } from './pages/pasal/PasalTrashPage'
import { PasalDetailPage } from './pages/pasal/PasalDetailPage'
import { UndangUndangListPage } from './pages/undang-undang/UndangUndangListPage'
import { BulkImportPage } from './pages/BulkImportPage'
import { AuditLogPage } from './pages/AuditLogPage'
import { AuditLogDetailPage } from './pages/AuditLogDetailPage'

// Protected Route wrapper
function ProtectedRoute({ children }: { children: React.ReactNode }) {
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
    <Routes>
      {/* Public Routes */}
      <Route path="/login" element={<LoginPage />} />

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
        <Route path="audit-log" element={<AuditLogPage />} />
        <Route path="audit-log/:id" element={<AuditLogDetailPage />} />
      </Route>

      {/* Catch all */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default App
