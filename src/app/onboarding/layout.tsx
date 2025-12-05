// src/app/onboarding/layout.tsx
export default function OnboardingLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900">
      {children}
    </div>
  )
}