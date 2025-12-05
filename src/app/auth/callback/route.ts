// src/app/auth/callback/route.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')

  if (code) {
    const cookieStore = cookies()
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          get: (name: string) => cookieStore.get(name)?.value,
          set: (name: string, value: string, options: any) => {
            requestUrl.searchParams.delete('code')
            const response = NextResponse.redirect(requestUrl, { headers: request.headers })
            response.cookies.set(name, value, options)
            return response
          },
          remove: (name: string, options: any) => {
            requestUrl.searchParams.delete('code')
            const response = NextResponse.redirect(requestUrl, { headers: request.headers })
            response.cookies.delete(name)
            return response
          },
        },
      }
    )
    await supabase.auth.exchangeCodeForSession(code)
  }

  return NextResponse.redirect(new URL('/welcome', request.url))
}