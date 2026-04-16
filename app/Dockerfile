# =============================================================
# Stage 1 — deps
# Install production dependencies only.
# Uses full Debian image so native bindings (mysql2) can compile.
# =============================================================
FROM node:20-bullseye AS deps

WORKDIR /build

COPY package.json package-lock.json ./

RUN npm ci --omit=dev --ignore-scripts

# =============================================================
# Stage 2 — runtime
# Minimal Alpine image — only app code + production node_modules.
# ~850 MB smaller than a single-stage bullseye build.
# =============================================================
FROM node:20-alpine AS runtime

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=deps /build/node_modules ./node_modules

COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

ENV NODE_ENV=development \
    PORT=8080

CMD ["node", "server.js"]
