import { Image, useComputedColorScheme } from '@mantine/core'
import logoLight from '@/assets/logo.png'
import logoDark from '@/assets/logo-dark.png'

/** Logo CariPasal (sama dengan aplikasi mobile); versi gelap dipakai di tema gelap. */
export function AppLogo({ size = 32 }: { size?: number }) {
  const scheme = useComputedColorScheme('light')
  return <Image src={scheme === 'dark' ? logoDark : logoLight} alt="Logo CariPasal" w={size} h={size} />
}
