import { defineConfig } from "astro/config";
import react from "@astrojs/react";
import tailwind from "@astrojs/tailwind";
import sitemap from '@astrojs/sitemap';
import node from '@astrojs/node';

export default defineConfig({
  site: 'https://ai-coding-site.netlify.app',
  output: 'hybrid',
  adapter: node({
    mode: 'standalone'
  }),
  integrations: [
    react(),
    tailwind({
      applyBaseStyles: false,
    }),
    sitemap({
      canonicalURL: 'https://ai-coding-site.netlify.app'
    })
  ],
  vite: {
    optimizeDeps: {
      include: ['monaco-editor']
    }
  }
});
