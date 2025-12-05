import { createMiddlewareClient } from '@supabase/ssr';
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export async function middleware(req: NextRequest) {
  const res = NextResponse.next();
  const supabase = createMiddlewareClient({ req, res });

  await supabase.auth.getSession();

  // Protect routes: if no session and not public paths, redirect
  if (
    !req.nextUrl.pathname.startsWith('/_next') &&
    !req.nextUrl.pathname.startsWith('/signin') &&
    !req.nextUrl.pathname === '/'
  ) {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
      return NextResponse.redirect(new URL('/signin', req.url));
    }
  }

  return res;
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
};