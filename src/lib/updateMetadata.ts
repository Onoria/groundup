'use server'

import { auth } from '@clerk/nextjs/server'
import { clerkClient } from '@clerk/nextjs/server'

export async function setQueued(queued: boolean) {
  const { userId } = auth()
  if (!userId) throw new Error('Unauthorized')

  await clerkClient.users.updateUserMetadata(userId, {
    publicMetadata: {
      queued,
      queuedAt: queued ? Date.now() : null,
    },
  })
}
