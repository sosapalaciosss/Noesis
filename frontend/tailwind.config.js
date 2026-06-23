/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Paleta institucional basada en azules profundos.
        navy: {
          950: "#060f24",
          900: "#0a1733",
          800: "#0e2148",
          700: "#13305f",
          600: "#1b417f",
          500: "#23529e",
        },
        brand: {
          50: "#eff5ff",
          100: "#dbe7fe",
          200: "#bfd3fe",
          300: "#93b4fd",
          400: "#608cfa",
          500: "#3b66f5",
          600: "#2548ea",
          700: "#1d37d7",
          800: "#1e30ae",
          900: "#1e2e89",
        },
      },
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui", "sans-serif"],
      },
      boxShadow: {
        soft: "0 1px 2px rgba(16,33,72,0.04), 0 8px 24px rgba(16,33,72,0.06)",
        panel: "0 1px 3px rgba(16,33,72,0.06), 0 12px 40px rgba(16,33,72,0.08)",
      },
    },
  },
  plugins: [],
};
