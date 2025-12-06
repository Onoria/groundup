'use server'

import { auth } from '@clerk/nextjs/server'
import { clerkClient } from '@clerk/nextjs/server'

export async function setQueued(queued: boolean) {
  const { userId } = await auth()
  
  if (!userId) {
    console.error('[setQueued] No userId – unauthorized')
    throw new Error('You must be signed in')
  }

  try {
    // v5: clerkClient is async → must await
    const client = await clerkClient()
    
    await client.users.updateUserMetadata(userId, {
      publicMetadata: {
        queued,
        queuedAt: queued ? Date.now() : null,
      },
    })

    console.log(`[setQueued] Success – user ${userId} queued = ${queued}`)
  } catch (error: any) {
    // This will show up in Vercel logs
    console.error('[setQueued] Failed:', error.message || error)
    
    // Show user-friendly message instead of 500
    throw new Error('Failed to join queue – please try again')
  }
}
