import { currentUser } from '@clerk/nextjs/server'
import { redirect } from 'next/navigation'

export default async function Dashboard() {
  const user = await currentUser()
  if (!user) redirect('/signin')

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <h1>Welcome, {user.firstName || user.emailAddresses[0].emailAddress}!</h1>
      <p>Ready to find your startup team?</p>
      {/* Your matching UI goes here */}
    </div>
  )
}
