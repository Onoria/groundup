import { authMiddleware } from '@clerk/nextjs/server'

export default authMiddleware({
  publicRoutes: ['/', '/sign-in(.*)', '/sign-up(.*)'],
  ignoredRoutes: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
})

export const config = {
  matcher: ['/((?!.+\\.[\\w]+$|_next).*)', '/', '/(api|trpc)(.*)'],
}
