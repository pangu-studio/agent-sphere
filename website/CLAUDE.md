# AgentSphere Website (React)

Next.js 16 + Tailwind CSS v4 + shadcn/ui marketing website for AgentSphere.

## Quick start

```sh
npm install
npm run dev        # http://localhost:3000
npm run build      # static export → out/
```

## Structure

```
src/
├── app/                    # Next.js App Router
│   ├── layout.tsx          # Root layout with metadata + I18nProvider
│   ├── page.tsx            # Single-page site (NavBar + 5 sections)
│   └── globals.css         # Tailwind v4 + shadcn/ui theme tokens
├── components/
│   ├── ui/                 # shadcn/ui primitives (button, card)
│   └── sections/           # Page sections
│       ├── NavBar.tsx      # Fixed nav with scroll detection + locale toggle
│       ├── HeroSection.tsx # Gradient hero with typewriter animation
│       ├── FeaturesSection.tsx  # 6 feature cards grid
│       ├── InstallSection.tsx   # Linux command + Win/Mac download cards
│       ├── HowItWorks.tsx       # 3-step guide with connecting lines
│       └── FooterSection.tsx    # Simple footer
├── hooks/
│   └── useTypewriter.ts    # Typewriter animation hook
├── i18n/
│   ├── index.tsx           # React context + localStorage persistence
│   ├── en-US.json          # English translations
│   └── zh-CN.json          # Chinese translations
└── lib/
    ├── utils.ts            # cn() helper (shadcn)
    └── version.ts          # Build-time version.json reader
```

## Key conventions

- **All components are Client Components** (`"use client"`) — the site is fully static but needs client-side i18n and interactivity.
- **i18n**: Language stored in `localStorage` key `tenbox-locale`, detected from `navigator.language`. Shares the same JSON translation format as the Vue `website/`.
- **Build-time env injection**: `next.config.ts` reads `public/api/version.json` at build time and injects `NEXT_PUBLIC_*` env vars for version, download URLs.
- **Static export**: `output: "export"` in next.config.ts → builds to `out/` directory (GitHub Pages compatible).
- **Tailwind v4**: Uses CSS-based config (`@theme inline`), not `tailwind.config.ts`. shadcn/ui v4 uses `@base-ui/react` primitives.
- **Icons**: `lucide-react` for most icons; inline SVGs for brand icons (GitHub, Windows) not in lucide's set.
