// src/app/page.tsx
import Link from 'next/link'

export default function Home() {
  return (
    <section className="space-y-4">
      <h1 className="text-3xl font-bold">GroundUp</h1>
      <p className="text-lg text-gray-600">
        Form balanced founding teams for tech startups or blue-collar empires.
      </p>
      <Link
        href="/signup"
        className="inline-flex rounded-md border px-4 py-2 text-sm"
      >
        Start Matching – $49/mo
      </Link>
    </section>
  )
}