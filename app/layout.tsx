import type { Metadata } from 'next'
import { ClerkProvider } from '@clerk/nextjs'
import { GeistSans } from 'geist/font/sans'
import './globals.css'

export const metadata: Metadata = {
  title: 'GroundUp',
  description: 'The Dungeon Finder for startup teams',
}

export const dynamic = 'force-dynamic'
export const revalidate = 0

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body className={GeistSans.className}>{children}</body>
      </html>
    </ClerkProvider>
  )
}
