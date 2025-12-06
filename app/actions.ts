'use server'

import { auth } from '@clerk/nextjs/server'
import { clerkClient } from '@clerk/nextjs/server'
import { revalidatePath } from 'next/cache'

export async function updateUserMetadata(prevState: { success: boolean }, formData: FormData) {
  const { userId } = await auth()
  if (!userId) return { success: false }

  const client = await clerkClient()
  const currentUser = await client.users.getUser(userId)
  const updates = {
    publicMetadata: {
      ...currentUser.publicMetadata || {},
      ...Object.fromEntries(formData.entries())
    }
  }

  await client.users.updateUserMetadata(userId, updates)
  revalidatePath('/dashboard')
  return { success: true }
}
