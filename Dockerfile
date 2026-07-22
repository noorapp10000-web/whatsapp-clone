FROM node:20-alpine
WORKDIR /app
COPY server/package*.json ./
RUN npm ci --only=production --no-audit --no-fund
COPY server/ .
EXPOSE 3000
CMD ["node", "index.js"]
