FROM node:20-slim AS frontend

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./
RUN npm run build


FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml README.md ./
COPY backend/ ./backend
COPY scripts/ ./scripts

COPY --from=frontend /app/frontend/dist ./backend/static

RUN pip install --no-cache-dir -U pip setuptools wheel \
    && pip install --no-cache-dir -e .

ENV HERMES_HOME=/root/.hermes
ENV PYTHONUNBUFFERED=1

EXPOSE 3001

CMD ["hermes-hudui", "--host", "0.0.0.0", "--port", "3001"]
