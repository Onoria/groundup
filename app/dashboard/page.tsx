import { auth, currentUser } from '@clerk/nextjs/server'
import { UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default async function Dashboard() {
  const { userId } = auth()
  const user = await currentUser()

  if (!userId) {
    return <RedirectToSignIn />
  }

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-4xl font-bold">Your GroundUp Dashboard</h1>
          <UserButton />
        </div>

        <div className="bg-white rounded-xl shadow-lg p-8">
          <p className="text-xl mb-4">
            Hey {user?.firstName || 'Founder'}! 👋
          </p>
          <p className="text-gray-600 mb-8">
            Ready to assemble your startup party? Let the matching begin.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <Link href="/match" className="p-6 bg-blue-600 text-white rounded-lg text-center hover:bg-blue-700 transition">
              <h3 className="text-2xl font-bold">Find Teammates</h3>
              <p className="mt-2">Run the matchmaking algorithm</p>
            </Link>
            <Link href="/team" className="p-6 bg-green-600 text-white rounded-lg text-center hover:bg-green-700 transition">
              <h3 className="text-2xl font-bold">My Party</h3>
              <p className="mt-2">View current team & progress</p>
            </Link>
            <div className="p-6 bg-purple-600 text-white rounded-lg text-center">
              <h3 className="text-2xl font-bold">Subscription Active</h3>
              <p className="mt-2">Paid monthly · Cancel anytime</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
