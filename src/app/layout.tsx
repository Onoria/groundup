// app/layout.tsx
import type { Metadata } from 'next'
import { ClerkProvider } from '@clerk/nextjs'
import { GeistSans } from 'geist/font/sans' // Or your font
import './globals.css'

export const metadata: Metadata = {
  title: 'GroundUp - Build Startups Like Dungeons',
  description: 'Matchmaking for entrepreneurs: Form teams, launch companies, track progress.',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body className={GeistSans.className}>
          {children}
        </body>
      </html>
    </ClerkProvider>
  )
}