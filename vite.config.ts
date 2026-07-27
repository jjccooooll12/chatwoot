import { defineConfig } from 'vite';
import ruby from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { aliases, vueOptions } from './vite.shared';
import yaml from '@rollup/plugin-yaml';

// When the Vite dev server runs behind an HTTPS reverse proxy (the hosted
// dev/preview box), VITE_DEV_PUBLIC_HOST points HMR at the public domain so the
// websocket connects over wss/443. Unset for local dev and production builds,
// where the default (localhost) behaviour is correct.
const devPublicHost = process.env.VITE_DEV_PUBLIC_HOST;

export default defineConfig({
  plugins: [ruby(), vue(vueOptions), yaml()],
  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler',
      },
    },
  },
  resolve: { alias: aliases },
  ...(devPublicHost
    ? {
        server: {
          host: '0.0.0.0',
          allowedHosts: true,
          hmr: { host: devPublicHost, protocol: 'wss', clientPort: 443 },
          // On Linux, inotify events from a host rsync propagate across the
          // bind mount, so no polling is needed (polling stat()s the whole tree
          // on a timer and blocks Node's event loop, slowing the HMR socket).
          // Pre-transform the SPA entry on boot so the first page load is warm.
          warmup: { clientFiles: ['./app/javascript/entrypoints/**/*.js'] },
        },
      }
    : {}),
});
