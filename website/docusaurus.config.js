// @ts-check
const path = require('path');

const ORG = 'untoldengine';
const REPO = 'UntoldEngine';
const isDev = process.env.NODE_ENV !== 'production';

/** @type {import('@docusaurus/types').Config} */
module.exports = {
  title: 'Untold Engine Docs',

  // Use dev/prod URLs correctly
  url: isDev ? 'http://localhost:3000' : `https://${ORG}.github.io`,
  baseUrl: isDev ? '/' : `/${REPO}/`,
  baseUrlIssueBanner: false,
  favicon: 'img/favicon.ico',

  organizationName: ORG,
  projectName: REPO,
  deploymentBranch: 'gh-pages',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: { defaultLocale: 'en', locales: ['en'] },

  presets: [
    [
      'classic',
      ({
        docs: {
          path: path.resolve(__dirname, '..', 'docs'),
          routeBasePath: '/docs',
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: `https://github.com/${ORG}/${REPO}/edit/master/docs/`,
          showLastUpdateTime: true,
          showLastUpdateAuthor: true,
        },
        blog: false,
        theme: { customCss: require.resolve('./src/css/custom.css') },
      }),
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'Untold Engine',
      items: [
        { to: '/docs/intro', label: 'Docs', position: 'left' },
        { href: `https://github.com/${ORG}/${REPO}`, label: 'GitHub', position: 'right' },
      ],
    },
    prism: { additionalLanguages: ['swift', 'c', 'cpp', 'hlsl', 'glsl'] },
  },
};

