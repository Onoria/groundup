'use server'

import { auth } from '@clerk/nextjs/server'
import { clerkClient } from '@clerk/nextjs/server'

export async function setQueued(queued: boolean) {
  const { userId } = await auth()
  if (!userId) throw new Error('Unauthorized')

  // Await the client factory (Clerk v5.6+ requirement)
  const client = await clerkClient()
  // Type assertion for TS lag (runtime is fine)
  const typedClient = client as typeof client & { users: { updateUserMetadata: (id: string, updates: { publicMetadata: any }) => Promise<any> } }

  await typedClient.users.updateUserMetadata(userId, {
    publicMetadata: {
      queued,
      queuedAt: queued ? Date.now() : null,
    },
  })
}
