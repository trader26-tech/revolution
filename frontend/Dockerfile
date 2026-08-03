# Frontend — Vite PWA, built then served with `vite preview`.
# Multi-stage: build with full devDependencies, then serve from a lean image.
FROM node:22-slim AS build

WORKDIR /app

# Install deps first (cached until package files change).
COPY package.json package-lock.json ./
RUN npm ci

# Build the production bundle (VITE_* vars must be present at build time —
# set them as Railway build args / variables to bake in the API URL).
COPY . .
RUN npm run build

# --- runtime image ---
FROM node:22-slim AS runtime
WORKDIR /app

# Only what's needed to serve: the build output, the vite config/preview
# host settings, and the deps vite preview relies on.
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/vite.config.ts ./vite.config.ts

# Do NOT set ENV PORT — Railway injects $PORT and routes the domain to it.
# serve:prod falls back to 4173 only for a local `docker run`.
EXPOSE 4173

# serve:prod → vite preview --host 0.0.0.0 --port ${PORT:-4173} (allowedHosts:
# true in vite.config.ts accepts the Railway public domain).
CMD npm run serve:prod
