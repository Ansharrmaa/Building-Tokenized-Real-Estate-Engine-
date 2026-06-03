FROM rust:1.75-slim as builder

# Install dependencies for building
RUN apt-get update && apt-get install -y pkg-config libssl-dev build-essential curl

WORKDIR /app

# Build the Rust application
COPY backend/ ./backend/
COPY scripts/ ./scripts/
COPY data/ ./data/
# Copy the compiled Flutter web files so the backend can serve them
COPY frontend/build/web/ ./frontend/build/web/

WORKDIR /app/backend
RUN cargo build --release

# -----------------
# Final Runtime Image
# -----------------
FROM debian:bookworm-slim

# Install sqlite3 and required runtime libraries
RUN apt-get update && apt-get install -y sqlite3 libssl3 ca-certificates curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download and install Meilisearch
RUN curl -L https://install.meilisearch.com | sh
RUN mv meilisearch /usr/local/bin/

# Copy artifacts from builder
COPY --from=builder /app/backend/target/release/tokenized-real-estate-backend /usr/local/bin/
COPY --from=builder /app/scripts /app/scripts
COPY --from=builder /app/frontend/build/web /frontend/build/web

# Copy the start script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Environment variables
ENV HOST=0.0.0.0
ENV PORT=3000
ENV DATABASE_URL=sqlite:///data/real_estate.db?mode=rwc
ENV MEILISEARCH_URL=http://127.0.0.1:7700
ENV MEILISEARCH_API_KEY=masterKey
ENV ADMIN_API_KEY=super-secret-admin-token-2024

EXPOSE 3000

CMD ["/app/start.sh"]
