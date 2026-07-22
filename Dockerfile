FROM node:22-slim

WORKDIR /app
COPY server/package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY server/ .
CMD ["node", "index.js"]
