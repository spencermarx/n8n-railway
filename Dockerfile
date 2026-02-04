FROM node:22-alpine

ARG N8N_VERSION=2.6.2

RUN apk add --update graphicsmagick tzdata

USER root

RUN apk --update add --virtual build-dependencies python3 build-base && \
    npm_config_user=root npm install --location=global n8n@${N8N_VERSION} && \
    apk del build-dependencies

WORKDIR /data

EXPOSE $PORT

ENV N8N_USER_ID=root
ENV NODE_FUNCTION_ALLOW_BUILTIN=crypto
# Allow Code nodes to access environment variables via $env
ENV N8N_BLOCK_ENV_ACCESS_IN_NODE=false

CMD export N8N_PORT=$PORT && n8n start
