FROM node:24-alpine

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

EXPOSE 8080

USER node

CMD ["node", "src/server.js"]
