import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// GitHub Pages: site = https://<user>.github.io, base = /<repo>
export default defineConfig({
  site: 'https://wraithyy.github.io',
  base: '/ancre',
  integrations: [
    starlight({
      title: 'ancre',
      description:
        'Hyprland-inspired tiling window manager for macOS — pure public Accessibility API.',
      logo: {
        light: './src/assets/ancre-horizontal-lockup-dark.svg',
        dark: './src/assets/ancre-horizontal-lockup.svg',
        replacesTitle: true,
      },
      favicon: '/favicon.svg',
      customCss: ['./src/styles/brand.css'],
      defaultLocale: 'root',
      locales: {
        root: { label: 'English', lang: 'en' },
        cs: { label: 'Čeština', lang: 'cs' },
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/wraithyy/ancre' },
      ],
      editLink: {
        baseUrl: 'https://github.com/wraithyy/ancre/edit/main/website/',
      },
      sidebar: [
        {
          label: 'Getting started',
          translations: { cs: 'Začínáme' },
          items: ['installation', 'controls'],
        },
        {
          label: 'Guides',
          translations: { cs: 'Příručky' },
          items: ['configuration', 'layouts', 'multi-monitor', 'bar', 'scripting'],
        },
        {
          label: 'Reference',
          translations: { cs: 'Reference' },
          items: ['config-reference', 'architecture', 'troubleshooting'],
        },
      ],
    }),
  ],
});
