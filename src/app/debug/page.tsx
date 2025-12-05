'use client'

import { useEffect } from 'react'

export default function Debug() {
  useEffect(() => {
    console.log("DEBUG: You were redirected here!")
    alert("DEBUG: Redirect worked! You are now on /debug")
  }, [])

  return (
    <div className="min-h-screen bg-red-950 text-white flex items-center justify-center text-4xl font-bold">
      DEBUG PAGE — REDIRECT WORKED!
    </div>
  )
}