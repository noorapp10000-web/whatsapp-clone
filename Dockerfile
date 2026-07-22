FROM node:22-slim

WORKDIR /app
COPY server/package.json ./
RUN npm install --omit=dev --no-audit --no-fund
COPY server/ .
EXPOSE 3000
ENV PORT=3000
CMD ["node", "index.js"]
