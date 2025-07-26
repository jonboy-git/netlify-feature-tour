import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import tailwind from "@astrojs/tailwind";
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://ultimate-ai-coding.netlify.app',
  integrations: [
    react(),
    tailwind({
      applyBaseStyles: false,
    }),
    sitemap({
      canonicalURL: 'https://ultimate-ai-coding.netlify.app'
    })
  ],
  vite: {
    optimizeDeps: {
      include: ['react', 'react-dom', '@monaco-editor/react']
    }
  }
});
