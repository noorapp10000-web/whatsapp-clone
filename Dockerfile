FROM node:20-slim
WORKDIR /app
COPY server/package.json server/package-lock.json ./
# Use npm install instead of npm ci — npm ci has a known "Exit handler never called" bug
# in npm 10.x inside node:20-slim that causes partial installs
RUN npm install --omit=dev --no-audit --no-fund --registry https://registry.npmjs.org
COPY server/ .
EXPOSE 3000
CMD ["node", "index.js"]
