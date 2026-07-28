/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  darkMode: ['class', ':root[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        ground: 'var(--ground)',
        surface: {
          DEFAULT: 'var(--surface)',
          2: 'var(--surface-2)',
        },
        ink: 'var(--ink)',
        muted: {
          DEFAULT: 'var(--muted)',
          soft: 'var(--muted-soft)',
        },
        hairline: 'var(--hairline)',
        field: 'var(--field-border)',
        'nav-idle': 'var(--nav-idle)',
        accent: {
          DEFAULT: 'var(--accent)',
          hover: 'var(--accent-hover)',
          text: 'var(--accent-text)',
          wash: 'var(--accent-wash)',
          wash2: 'var(--accent-wash-2)',
        },
        good: { DEFAULT: 'var(--good)', wash: 'var(--good-wash)' },
        info: { DEFAULT: 'var(--info)', wash: 'var(--info-wash)' },
        warn: { DEFAULT: 'var(--warn)', wash: 'var(--warn-wash)' },
        crit: { DEFAULT: 'var(--crit)', wash: 'var(--crit-wash)' },
      },
      borderRadius: {
        shell: '28px',
        card: '18px',
        nav: '12px',
        pill: '999px',
      },
      boxShadow: {
        shell: 'var(--shadow-shell)',
        card: 'var(--shadow-card)',
        pop: 'var(--shadow-pop)',
      },
      fontFamily: {
        display: ['Poppins', 'Segoe UI Variable Display', 'system-ui', 'sans-serif'],
        sans: ['Poppins', 'Segoe UI', 'system-ui', 'sans-serif'],
      },
      transitionDuration: {
        DEFAULT: '140ms',
      },
    },
  },
  plugins: [],
};
