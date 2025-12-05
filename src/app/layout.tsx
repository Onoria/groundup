import { ClerkProvider } from '@clerk/nextjs'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'GroundUp - Startup Dungeon Finder',
  description: 'Find your co-founders: 1 Founder + 1 Dev + 1 Designer',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body className="min-h-screen bg-gray-50">
          {children}
        </body>
      </html>
    </ClerkProvider>
  )
}
