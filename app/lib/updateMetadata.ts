'use server'

import { auth } from '@clerk/nextjs/server'
import { clerkClient } from '@clerk/nextjs/server'

export async function setQueued(queued: boolean) {
  const { userId } = await auth()
  if (!userId) throw new Error('Unauthorized')

  try {
    await clerkClient.users.updateUserMetadata(userId, {
      publicMetadata: {
        queued,
        queuedAt: queued ? Date.now() : null,
      },
    })
  } catch (error) {
    console.error('[setQueued] Failed to update metadata:', error)
    throw new Error(
      `Failed to ${queued ? 'join' : 'leave'} the queue. Please try again.`
    )
  }
}

export async function setRole(role: string) {
  const { userId } = await auth()
  if (!userId) throw new Error('Unauthorized')

  try {
    await clerkClient.users.updateUserMetadata(userId, {
      publicMetadata: { role },
    })
  } catch (error) {
    console.error('[setRole] Failed to update role:', error)
    throw new Error('Failed to save role. Please try again.')
  }
}
