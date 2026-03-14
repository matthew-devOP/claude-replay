FROM node:22-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --production=false

COPY . .
RUN npm run build

EXPOSE 7331

CMD ["node", "bin/claude-replay.mjs", "--port", "7331", "--host", "0.0.0.0"]
