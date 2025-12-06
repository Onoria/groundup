import type { Metadata } from "next";
import "./globals.css";
import { ClerkProvider } from "@clerk/nextjs";

export const metadata: Metadata = {
  title: "GroundUp",
  description: "Build real companies from the ground up.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <ClerkProvider>
      <html lang="en" className="h-full">
        <body className="min-h-screen bg-slate-950 text-slate-100 antialiased">
          <div className="relative min-h-screen overflow-hidden bg-slate-950">
            <div className="pointer-events-none absolute inset-0 opacity-50">
              <div className="absolute -top-40 -left-40 h-80 w-80 rounded-full bg-emerald-500/20 blur-3xl" />
              <div className="absolute -bottom-40 -right-40 h-80 w-80 rounded-full bg-cyan-500/15 blur-3xl" />
            </div>

            <div className="relative z-10 flex min-h-screen flex-col">
              <main className="mx-auto flex w-full max-w-6xl flex-1 flex-col px-4 pb-10 pt-6 sm:px-6 lg:px-8 lg:pt-10">
                {children}
              </main>
            </div>
          </div>
        </body>
      </html>
    </ClerkProvider>
  );
}
