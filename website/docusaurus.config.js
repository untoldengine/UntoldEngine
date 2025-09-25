// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const path = require('path');

const ORG = 'untoldengine';
const REPO = 'UntoldEngine';
const isDev = process.env.NODE_ENV !== 'production';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Untold Engine Docs',
  url: isDev ? 'http://localhost:3000' : 'https://${ORG}.github.io',   // dev URL
  baseUrl: isDev ? '/' : '/${REPO}/',                   // mount at root for local dev
  baseUrlIssueBanner: false,
  favicon: 'img/favicon.ico',

  organizationName: ORG,
  projectName: REPO,
  deploymentBranch: 'gh-pages',
  trailingSlash: false,

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
          editUrl: 'https://github.com/${ORG}/${REPO}/edit/master/docs/',
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
        { href: 'https://github.com/${ORG}/${REPO}', label: 'GitHub', position: 'right' },
      ],
    },
    prism: { additionalLanguages: ['swift', 'c', 'cpp', 'hlsl', 'glsl'] },
  },
};

module.exports = config;

