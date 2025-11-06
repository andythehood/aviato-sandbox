# servers/gateway/Dockerfile

# Build stage
FROM node:22-alpine AS builder
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# Copy root workspace files
COPY pnpm-lock.yaml package.json .npmrc pnpm-workspace.yaml ./

# Copy workspace packages (monorepo structure)
COPY servers/users ./servers/users

# Install only deps for this workspace package
RUN pnpm install --filter ./servers/users... --frozen-lockfile

# Build that package
WORKDIR /app/servers/users
RUN pnpm run build 

# Runtime
FROM node:22-alpine AS runner
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY --from=builder /app/servers/users/dist ./dist
COPY --from=builder /app/servers/users/package.json  ./
# COPY --from=builder /app/servers/gateway/pnpm-lock.yaml ./
# RUN pnpm install --prod --filter . 
RUN pnpm install --prod --filter . --no-frozen-lockfile
ENV PORT=8080
EXPOSE 8080
CMD ["node", "dist/index.js"]
