import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
    // Force Tailwind to keep md:grid-cols-3 even if it thinks it's unused
    './app/page.tsx',
  ],
  theme: {
    extend: {
      gridTemplateColumns: {
        // This makes md:grid-cols-3 always available
        '3': 'repeat(3, minmax(0, 1fr))',
      },
    },
  },
  plugins: [],
}
export default config
