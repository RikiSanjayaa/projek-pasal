import { createContext, useContext, ReactNode } from 'react'
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

interface DataMappingContextType {
  undangUndangData: { id: string; nama: string }[] | undefined
  pasalData: { id: string; nomor: string; undang_undang_id: string }[] | undefined
  isLoading: boolean
  error: Error | null
}

const DataMappingContext = createContext<DataMappingContextType | undefined>(undefined)

interface DataMappingProviderProps {
  children: ReactNode
}

export function DataMappingProvider({ children }: DataMappingProviderProps) {
  // Fetch undang_undang for mapping IDs to names
  const { data: undangUndangData, isLoading: loadingUU, error: errorUU } = useQuery({
    queryKey: ['data_mapping', 'undang_undang'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('undang_undang')
        .select('id, nama')
        .eq('is_active', true)
      if (error) throw error
      return data as { id: string; nama: string }[]
    },
    staleTime: 30 * 1000, // 30 seconds - more frequent for dashboard usage
    gcTime: 5 * 60 * 1000, // 5 minutes
    refetchInterval: 60 * 1000, // Auto-refresh every minute
  })

  // Fetch pasal for mapping IDs to numbers
  const { data: pasalData, isLoading: loadingPasal, error: errorPasal } = useQuery({
    queryKey: ['data_mapping', 'pasal'],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('pasal')
        .select('id, nomor, undang_undang_id')
        .is('deleted_at', null)
      if (error) throw error
      return data as { id: string; nomor: string; undang_undang_id: string }[]
    },
    staleTime: 30 * 1000, // 30 seconds - more frequent for dashboard usage
    gcTime: 5 * 60 * 1000, // 5 minutes
    refetchInterval: 60 * 1000, // Auto-refresh every minute
  })

  const isLoading = loadingUU || loadingPasal
  const error = errorUU || errorPasal

  return (
    <DataMappingContext.Provider value={{
      undangUndangData,
      pasalData,
      isLoading,
      error
    }}>
      {children}
    </DataMappingContext.Provider>
  )
}

export function useDataMapping() {
  const context = useContext(DataMappingContext)
  if (context === undefined) {
    throw new Error('useDataMapping must be used within a DataMappingProvider')
  }
  return context
}