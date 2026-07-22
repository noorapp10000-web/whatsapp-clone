FROM node:20-slim
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server/ .
EXPOSE 3000
CMD ["node", "index.js"]
