/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        'bingo-pink': '#ff69b4',
        'bingo-purple': '#9d4edd',
        'bingo-gold': '#ffd700',
        'casino-red': '#dc2626',
        'casino-green': '#059669',
        'casino-black': '#1f2937',
      },
      animation: {
        'spin-slow': 'spin 3s linear infinite',
        'bounce-slow': 'bounce 2s infinite',
        'pulse-fast': 'pulse 1s linear infinite',
      },
      fontFamily: {
        'fancy': ['Georgia', 'serif'],
      }
    },
  },
  plugins: [],
}