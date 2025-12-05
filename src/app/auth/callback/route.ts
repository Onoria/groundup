// src/app/auth/callback/route.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const code = searchParams.get('code')

  let response = NextResponse.next()

  if (code) {
    const cookieStore = await cookies()
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          get: (name: string) => cookieStore.get(name)?.value,
          set: (name: string, value: string, options: any) => {
            response.cookies.set(name, value, options)
          },
          remove: (name: string, options: any) => {
            response.cookies.delete(name)
          },
        },
      }
    )

    await supabase.auth.exchangeCodeForSession(code)
  }

  // This is the magic — we return the response with cookies, then redirect
  return NextResponse.redirect(new URL('/welcome', request.url), { headers: response.headers })
}