FROM node:20-slim

# Upgrade npm first — npm 10.8.2 bundled in node:20-slim has a critical
# "Exit handler never called" bug that causes npm install to exit without
# actually installing packages (node_modules stays empty).
RUN npm install -g npm@12.0.1 --no-audit --no-fund

WORKDIR /app
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server/ .
EXPOSE 3000
CMD ["node", "index.js"]
