# Build context is the REPO ROOT (see docker-compose.yml: `context: .`,
# `dockerfile: examples/express-api/Dockerfile`) because this service
# depends on the local ../../client package via a `file:` reference,
# which must be present at the same relative path during `npm install`.
FROM node:22-alpine AS builder
WORKDIR /app
COPY client ./client
COPY examples/express-api ./examples/express-api
WORKDIR /app/examples/express-api
RUN npm install
RUN npm run build

FROM node:22-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/examples/express-api/dist ./dist
COPY --from=builder /app/examples/express-api/node_modules ./node_modules
COPY --from=builder /app/examples/express-api/package.json ./package.json
EXPOSE 4000
CMD ["node", "dist/server.js"]
