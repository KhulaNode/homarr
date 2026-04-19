FROM node:24.14.1-alpine AS base
RUN apk add --no-cache libc6-compat curl bash && apk update

FROM base AS builder
WORKDIR /app
# python3/make/g++ are required by native modules (better-sqlite3, bcrypt, ssh2, tree-sitter)
RUN apk add --no-cache python3 make g++
RUN corepack enable pnpm

# Copy only manifests + lockfile first so pnpm install is cached independently
# of source changes. pnpm install only re-runs when these files change.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json .npmrc ./
COPY patches ./patches
COPY apps/nextjs/package.json ./apps/nextjs/
COPY apps/tasks/package.json ./apps/tasks/
COPY apps/websocket/package.json ./apps/websocket/
COPY packages/analytics/package.json ./packages/analytics/
COPY packages/api/package.json ./packages/api/
COPY packages/auth/package.json ./packages/auth/
COPY packages/boards/package.json ./packages/boards/
COPY packages/cli/package.json ./packages/cli/
COPY packages/common/package.json ./packages/common/
COPY packages/core/package.json ./packages/core/
COPY packages/cron-job-api/package.json ./packages/cron-job-api/
COPY packages/cron-job-status/package.json ./packages/cron-job-status/
COPY packages/cron-jobs-core/package.json ./packages/cron-jobs-core/
COPY packages/cron-jobs/package.json ./packages/cron-jobs/
COPY packages/db/package.json ./packages/db/
COPY packages/definitions/package.json ./packages/definitions/
COPY packages/docker/package.json ./packages/docker/
COPY packages/form/package.json ./packages/form/
COPY packages/forms-collection/package.json ./packages/forms-collection/
COPY packages/icons/package.json ./packages/icons/
COPY packages/image-proxy/package.json ./packages/image-proxy/
COPY packages/integrations/package.json ./packages/integrations/
COPY packages/modals-collection/package.json ./packages/modals-collection/
COPY packages/modals/package.json ./packages/modals/
COPY packages/notifications/package.json ./packages/notifications/
COPY packages/old-import/package.json ./packages/old-import/
COPY packages/old-schema/package.json ./packages/old-schema/
COPY packages/ping/package.json ./packages/ping/
COPY packages/redis/package.json ./packages/redis/
COPY packages/request-handler/package.json ./packages/request-handler/
COPY packages/server-settings/package.json ./packages/server-settings/
COPY packages/settings/package.json ./packages/settings/
COPY packages/spotlight/package.json ./packages/spotlight/
COPY packages/translation/package.json ./packages/translation/
COPY packages/ui/package.json ./packages/ui/
COPY packages/validation/package.json ./packages/validation/
COPY packages/widgets/package.json ./packages/widgets/
COPY tooling/eslint/package.json ./tooling/eslint/
COPY tooling/github/package.json ./tooling/github/
COPY tooling/prettier/package.json ./tooling/prettier/
COPY tooling/typescript/package.json ./tooling/typescript/

# Cache the pnpm store across builds with BuildKit cache mount.
# --ignore-scripts skips postinstall/install scripts so no source is needed here,
# keeping this layer fully cached on UI-only changes.
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --recursive --frozen-lockfile --ignore-scripts

# Copy full source — only invalidates the build layer, not the install layer
COPY . .

# Copy static data as it is not part of the build
COPY static-data ./static-data

# Compile the native/runtime binaries whose install scripts were skipped above.
RUN pnpm rebuild esbuild bcrypt sharp && \
    cd node_modules/better-sqlite3 && npm run install && \
    cd /app && \
    test -f node_modules/better-sqlite3/build/Release/better_sqlite3.node
ARG SKIP_ENV_VALIDATION='true'
ARG CI='true'
ARG DISABLE_REDIS_LOGS='true'

RUN pnpm build

FROM base AS runner
WORKDIR /app

# gettext is required for envsubst, openssl for generating AUTH_SECRET, su-exec for running application as non-root
RUN apk add --no-cache redis nginx bash gettext su-exec openssl && \
    mkdir /appdata && \
    mkdir -p /var/cache/nginx /var/log/nginx /var/lib/nginx && \
    touch /run/nginx/nginx.pid && \
    mkdir -p /etc/nginx/templates /etc/nginx/ssl/certs
VOLUME /appdata

# Enable homarr cli
COPY --from=builder /app/packages/cli/cli.cjs /app/apps/cli/cli.cjs
RUN echo $'#!/bin/bash\ncd /app/apps/cli && node ./cli.cjs "$@"' > /usr/bin/homarr && \
    chmod +x /usr/bin/homarr

COPY --from=builder /app/apps/nextjs/next.config.ts .
COPY --from=builder /app/apps/nextjs/package.json .

COPY --from=builder /app/apps/tasks/tasks.cjs ./apps/tasks/tasks.cjs
COPY --from=builder /app/apps/websocket/wssServer.cjs ./apps/websocket/wssServer.cjs
COPY --from=builder /app/node_modules/better-sqlite3/build/Release/better_sqlite3.node /app/build/better_sqlite3.node

COPY --from=builder /app/packages/db/migrations ./db/migrations

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder /app/apps/nextjs/.next/standalone ./
COPY --from=builder /app/apps/nextjs/.next/static ./apps/nextjs/.next/static
COPY --from=builder /app/apps/nextjs/public ./apps/nextjs/public
COPY scripts/run.sh ./run.sh
COPY --chmod=755 scripts/entrypoint.sh ./entrypoint.sh
COPY packages/redis/redis.conf /app/redis.conf
COPY nginx.conf /etc/nginx/templates/nginx.conf


ENV DB_URL='/appdata/db/db.sqlite'
ENV DB_DIALECT='sqlite'
ENV DB_DRIVER='better-sqlite3'
ENV AUTH_PROVIDERS='credentials'
ENV REDIS_IS_EXTERNAL='false'
ENV NODE_ENV='production'

ENTRYPOINT [ "/app/entrypoint.sh" ]
CMD ["sh", "run.sh"]
