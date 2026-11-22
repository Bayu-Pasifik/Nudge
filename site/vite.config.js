import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// GitHub Pages serves a project site from /<repo>/. Override with BASE=/ for a
// custom domain or local preview at the root.
export default defineConfig({
  base: process.env.BASE ?? '/Nudge/',
  plugins: [react()],
});
