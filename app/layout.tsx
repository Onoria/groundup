import type { Metadata } from "next";
import "./globals.css";
import { ClerkProvider, SignedIn, SignedOut, SignInButton, UserButton } from "@clerk/nextjs";

export const metadata: Metadata = {
  title: "GroundUp",
  description: "Form balanced founding teams for tech startups or blue-collar empires.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>
          <div className="relative min-h-screen overflow-hidden bg-slate-950">
            <div className="pointer-events-none absolute inset-0 opacity-50">
              <div className="absolute -top-40 -left-40 h-80 w-80 rounded-full bg-emerald-500/20 blur-3xl" />
              <div className="absolute -bottom-40 -right-40 h-80 w-80 rounded-full bg-cyan-500/15 blur-3xl" />
            </div>

            <div className="bg-grid pointer-events-none absolute inset-0 opacity-40" />

            <div className="relative z-10 flex min-h-screen flex-col">
              <header className="mx-auto w-full max-w-6xl px-4 pt-5 sm:px-6 lg:px-8">
                <div className="flex items-center justify-between rounded-2xl border border-slate-800/80 bg-slate-900/70 px-4 py-3 shadow-lg shadow-black/40 backdrop-blur-xl sm:px-5">
                  <div className="flex items-center gap-2">
                    <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-emerald-400 to-cyan-400 text-slate-950 font-semibold">
                      GU
                    </div>
                    <div>
                      <div className="text-sm font-semibold tracking-tight text-slate-100">
                        GroundUp
                      </div>
                      <div className="text-xs text-slate-400">
                        Founding teams, not cofounder roulette
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-6">
                    <SignedOut>
                      <SignInButton mode="modal">
                        <button className="text-slate-400 hover:text-white transition text-sm font-medium">
                          Sign in
                        </button>
                      </SignInButton>
                    </SignedOut>
                    <SignedIn>
                      <UserButton afterSignOutUrl="/" />
                    </SignedIn>
                  </div>
                </div>
              </header>

              <main className="mx-auto flex w-full max-w-6xl flex-1 flex-col px-4 pb-10 pt-6 sm:px-6 lg:px-8 lg:pt-10">
                {children}
              </main>

              <footer className="mx-auto mt-6 w-full max-w-6xl px-4 pb-6 pt-2 text-xs text-slate-500 sm:px-6 lg:px-8">
                <div className="flex flex-col items-center justify-between gap-2 border-t border-slate-800/80 pt-4 sm:flex-row">
                  <p>© {new Date().getFullYear()} GroundUp. All rights reserved.</p>
                  <div className="flex gap-4">
                    <a className="hover:text-emerald-400 transition-colors" href="#">
                      Terms
                    </a>
                    <a className="hover:text-emerald-400 transition-colors" href="#">
                      Privacy
                    </a>
                  </div>
                </div>
              </footer>
            </div>
          </div>
        </body>
      </html>
    </ClerkProvider>
  );
}
