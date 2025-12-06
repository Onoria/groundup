'use server'

import { auth, clerkClient, currentUser } from '@clerk/nextjs/server'
import { revalidatePath } from 'next/cache'

export async function updateUserMetadata(formData: FormData) {
  const { userId } = await auth()
  if (!userId) throw new Error('Unauthorized')

  const client = await clerkClient()
  const updates = {
    publicMetadata: {
      ...(await currentUser())?.publicMetadata || {},
      ...Object.fromEntries(formData.entries())
    }
  }

  await client.users.updateUserMetadata(userId, updates)
  revalidatePath('/dashboard') // Refresh dashboard cache
  return { success: true }
}
