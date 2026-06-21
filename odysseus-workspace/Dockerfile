FROM node:20-alpine

WORKDIR /app

COPY odysseus-workspace/package.json odysseus-workspace/package-lock.json* ./odysseus-workspace/
RUN cd odysseus-workspace && npm ci --omit=dev 2>/dev/null || (cd odysseus-workspace && npm install --omit=dev)

COPY odysseus-workspace ./odysseus-workspace
COPY services/geod ./services/geod
COPY agents/geod_scheduler_agent.py ./agents/geod_scheduler_agent.py

RUN cd odysseus-workspace && npm run build

ENV NODE_ENV=production
ENV ODYSSEUS_BIND_HOST=0.0.0.0
ENV ODYSSEUS_BIND_PORT=7000
ENV PYTHON_BIN=python3

RUN apk add --no-cache python3

EXPOSE 7000

CMD ["node", "odysseus-workspace/dist/index.js"]
