import { clerkMiddleware } from '@clerk/nextjs/server'

export default clerkMiddleware((auth, req) => {
  // Protect everything except the sign-in/up and home page
  if (!req.nextUrl.pathname.startsWith('/sign-in') &&
      !req.nextUrl.pathname.startsWith('/sign-up') &&
      req.nextUrl.pathname !== '/') {
    auth().protect()
  }
})

export const config = {
  matcher: ['/((?!.*\\..*|_next).*)', '/', '/(api|trpc)(.*)'],
}
