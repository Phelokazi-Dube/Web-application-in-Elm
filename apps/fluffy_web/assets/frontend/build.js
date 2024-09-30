const esbuild = require('esbuild');
const ElmPlugin = require('esbuild-plugin-elm');

const isProduction = process.env.MIX_ENV === "prod"

async function watch() {
  const ctx = await esbuild.context({
    entryPoints: ['all_surveys.js', 'contact.js', 'downloading_data.js', 'home.js', 'publish_data.js', 'surveys.js', 'uploading_data.js', 'sign_up.js'],
    bundle: true,
    outdir: '../../priv/static/js',
    format: 'esm',
    plugins: [
      ElmPlugin({
        debug: true
      }),
    ],
  }).catch(_e => process.exit(1))
  await ctx.watch()
}

async function build() {
  await esbuild.build({
    entryPoints: ['all_surveys.js', 'contact.js', 'downloading_data.js', 'home.js', 'publish_data.js', 'surveys.js', 'uploading_data.js', 'sign_up.js'],
    bundle: true,
    minify: true,
    outdir: '../js',
    format: 'esm',
    plugins: [
      ElmPlugin(),
    ],
  }).catch(_e => process.exit(1))
}

if (isProduction)
  build()
else
  watch()