FROM node:24-slim

WORKDIR /app/server

ENV NODE_ENV=production
ENV PORT=8080
ENV ACCOUNT_DB_PATH=/data/accounts.sqlite
ENV APPLE_CLIENT_ID=com.shary.kraspass

COPY server/package*.json ./
RUN npm ci --omit=dev

COPY server/ ./

EXPOSE 8080

CMD ["npm", "start"]
