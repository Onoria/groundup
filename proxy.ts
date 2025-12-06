import { clerkMiddleware } from '@clerk/nextjs/server'

export default clerkMiddleware({
  publicRoutes: ['/', '/sign-in(.*)', '/sign-up(.*)'],
})

export const config = {
  matcher: [
    // Skip Next.js internals and static files
    '/((?!.*\\..*|_next).*)',
    '/',
    '/(api|trpc)(.*)',
  ],
}
