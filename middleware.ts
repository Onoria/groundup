import { authMiddleware } from "@clerk/nextjs/server"

export default authMiddleware({
  publicRoutes: ["/", "/signin", "/signup", "/welcome"],
})

export const config = {
  matcher: ["/((?!.*\\..*|_next).*)", "/", "/(api|trpc)(.*)"],
}
