// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const path = require('path');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Untold Engine Docs',
  url: 'http://localhost:3000',   // dev URL
  baseUrl: '/',                   // mount at root for local dev
  favicon: 'img/favicon.ico',

  // keep defaults
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',
  i18n: { defaultLocale: 'en', locales: ['en'] },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          // ⬇️ use your repo-root docs
          path: path.resolve(__dirname, '..', 'docs'),
          routeBasePath: '/docs', // docs at /docs (keeps / for the homepage)
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/untoldengine/UntoldEngine/edit/master/docs/',
        },
        blog: false,
        theme: { customCss: require.resolve('./src/css/custom.css') },
      }),
    ],
  ],


  themeConfig: {
    navbar: {
      title: 'Untold Engine',
//      logo: { alt: 'Untold', src: 'img/logo.svg' },
      items: [
        { to: '/docs/intro', label: 'Docs', position: 'left' },
        { href: 'https://github.com/untoldengine/UntoldEngine', label: 'GitHub', position: 'right' },
      ],
    },
    prism: { additionalLanguages: ['swift', 'objectivec', 'c', 'cpp', 'hlsl', 'glsl'] },
  },
};

module.exports = config;

