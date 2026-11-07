import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { Badge, Card, MantineProvider, Tooltip, createTheme } from '@mantine/core'
import { DatesProvider } from '@mantine/dates'
import { ModalsProvider } from '@mantine/modals'
import { Notifications } from '@mantine/notifications'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter } from 'react-router-dom'
import 'dayjs/locale/id'

import '@mantine/core/styles.css'
import '@mantine/dates/styles.css'
import '@mantine/notifications/styles.css'
import '@mantine/dropzone/styles.css'
import './styles.css'

import App from './App'
import { AuthProvider } from './contexts/AuthContext'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30 * 1000, // 30 seconds - more aggressive for real-time app
      refetchOnMount: 'always',
      refetchOnWindowFocus: true,
      retry: 1,
    },
  },
})

const theme = createTheme({
  primaryColor: 'blue',
  defaultRadius: 'md',
  fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif',
  headings: {
    fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif',
  },
  components: {
    // Badge Mantine memotong label ("AK...") di sel tabel yang sempit; label pendek harus utuh.
    Badge: Badge.extend({
      styles: { root: { textTransform: 'none', minWidth: 'max-content' } },
    }),
    Card: Card.extend({ defaultProps: { withBorder: true, radius: 'md' } }),
    Tooltip: Tooltip.extend({ defaultProps: { withArrow: true } }),
  },
})

const routerBasename = import.meta.env.VITE_APP_BASE_PATH?.replace(/\/$/, '') || '/'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <MantineProvider theme={theme} defaultColorScheme="light">
        <DatesProvider settings={{ locale: 'id', firstDayOfWeek: 1 }}>
          <Notifications position="top-right" />
          <ModalsProvider>
            <BrowserRouter basename={routerBasename} future={{ v7_relativeSplatPath: true, v7_startTransition: true }}>
              <AuthProvider>
                <App />
              </AuthProvider>
            </BrowserRouter>
          </ModalsProvider>
        </DatesProvider>
      </MantineProvider>
    </QueryClientProvider>
  </StrictMode>
)
