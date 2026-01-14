/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Match mobile app colors
        scaffold: {
          light: '#F5F7FA',
          dark: '#121212',
        },
        card: {
          light: '#FFFFFF',
          dark: '#1E1E1E',
        },
      },
    },
  },
  plugins: [require("daisyui")],
  daisyui: {
    themes: [
      {
        light: {
          "primary": "#3b82f6", // blue-500
          "secondary": "#22c55e", // green-500
          "accent": "#f59e0b", // amber-500
          "neutral": "#374151", // gray-700
          "base-100": "#F5F7FA",
          "base-200": "#FFFFFF",
          "base-300": "#E5E7EB",
          "info": "#3b82f6",
          "success": "#22c55e",
          "warning": "#f59e0b",
          "error": "#ef4444",
        },
        dark: {
          "primary": "#3b82f6",
          "secondary": "#22c55e",
          "accent": "#f59e0b",
          "neutral": "#1f2937",
          "base-100": "#121212",
          "base-200": "#1E1E1E",
          "base-300": "#2C2C2C",
          "info": "#3b82f6",
          "success": "#22c55e",
          "warning": "#f59e0b",
          "error": "#ef4444",
        },
      },
    ],
  },
}
