FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:18-alpine AS production
WORKDIR /app
RUN apk add --no-cache tini curl
RUN addgroup -g 1001 -S ziprick && adduser -S ziprick -u 1001 -G ziprick
COPY --from=builder /app/node_modules ./node_modules
COPY . .
RUN mkdir -p /app/logs && chown -R ziprick:ziprick /app/logs
USER ziprick
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4000/api/v1/health || exit 1
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/server.js"]
