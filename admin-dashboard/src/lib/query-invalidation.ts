import type { QueryClient } from '@tanstack/react-query'

export async function invalidateAdminData(queryClient: QueryClient) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: ['dashboard'] }),
    queryClient.invalidateQueries({ queryKey: ['data_mapping'] }),
    queryClient.invalidateQueries({ queryKey: ['audit_logs'] }),
    queryClient.invalidateQueries({ queryKey: ['audit_log'] }),
    queryClient.invalidateQueries({ queryKey: ['undang_undang'] }),
    queryClient.invalidateQueries({ queryKey: ['pasal'] }),
    queryClient.invalidateQueries({ queryKey: ['pasal_links'] }),
    queryClient.invalidateQueries({ queryKey: ['keywords'] }),
    queryClient.invalidateQueries({ queryKey: ['mobile_users'] }),
    queryClient.invalidateQueries({ queryKey: ['admin_users'] }),
  ])
}

export async function invalidatePasalData(queryClient: QueryClient) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: ['dashboard'] }),
    queryClient.invalidateQueries({ queryKey: ['data_mapping', 'pasal'] }),
    queryClient.invalidateQueries({ queryKey: ['audit_logs'] }),
    queryClient.invalidateQueries({ queryKey: ['pasal'] }),
    queryClient.invalidateQueries({ queryKey: ['pasal_links'] }),
    queryClient.invalidateQueries({ queryKey: ['keywords'] }),
  ])
}

export async function invalidateUndangUndangData(queryClient: QueryClient) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: ['dashboard'] }),
    queryClient.invalidateQueries({ queryKey: ['data_mapping', 'undang_undang'] }),
    queryClient.invalidateQueries({ queryKey: ['audit_logs'] }),
    queryClient.invalidateQueries({ queryKey: ['undang_undang'] }),
    queryClient.invalidateQueries({ queryKey: ['pasal'] }),
  ])
}
