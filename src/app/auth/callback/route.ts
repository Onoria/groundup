// src/app/auth/callback/route.ts
import { createServerSupabaseClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')

  const supabase = createServerSupabaseClient()

  if (code) {
    await supabase.auth.exchangeCodeForSession(code)
  }

  // Force no-cache to ensure session is read on next page
  const response = NextResponse.redirect(`${origin}/welcome`)
  response.headers.set('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate')

  return response
}