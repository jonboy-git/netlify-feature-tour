import { defineConfig } from "astro/config";
import preact from "@astrojs/preact";
import sitemap from '@astrojs/sitemap';
import tailwind from "@astrojs/tailwind";

export default defineConfig({
  site: 'https://pretty-little-bingo.netlify.app',
  integrations: [
    preact(),
    tailwind(),
    sitemap({
      canonicalURL: 'https://pretty-little-bingo.netlify.app'
    })
  ],
});
