# Multi-stage build for MCP-Jujutsu
# Stage 1: Build stage
FROM nimlang/nim:2.0.2-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    curl \
    gcc \
    musl-dev \
    openssl-dev \
    pcre-dev

# Set working directory
WORKDIR /app

# Copy nimble files first for better caching
COPY mcp_jujutsu.nimble ./
COPY nim.cfg ./
COPY nimble.cfg ./

# Install Nim dependencies
RUN nimble refresh && nimble install -y

# Copy source code
COPY src/ ./src/
COPY tests/ ./tests/
COPY scripts/ ./scripts/
COPY docs/ ./docs/
COPY examples/ ./examples/

# Build the application
RUN nimble build -d:release --opt:size

# Stage 2: Runtime stage
FROM alpine:3.19

# Install runtime dependencies including Jujutsu
RUN apk add --no-cache \
    ca-certificates \
    git \
    openssh-client \
    pcre \
    libssl3 \
    libcrypto3 \
    bash \
    curl

# Install Jujutsu
RUN curl -L https://github.com/martinvonz/jj/releases/latest/download/jj-linux-x86_64.tar.gz | tar xz -C /usr/local/bin

# Create non-root user
RUN addgroup -g 1000 -S mcp && \
    adduser -u 1000 -S mcp -G mcp

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/mcp_jujutsu /usr/local/bin/mcp_jujutsu

# Copy configuration files and examples
COPY --from=builder /app/docs /app/docs
COPY --from=builder /app/examples /app/examples
COPY card/card.json /app/card/card.json

# Create directories for repositories and configuration
RUN mkdir -p /app/repos /app/config && \
    chown -R mcp:mcp /app

# Switch to non-root user
USER mcp

# Expose default MCP server port
EXPOSE 8080

# Set environment variables
ENV MCP_JUJUTSU_MODE=single
ENV MCP_JUJUTSU_REPO_PATH=/app/repos
ENV MCP_JUJUTSU_HTTP_HOST=0.0.0.0
ENV MCP_JUJUTSU_HTTP_PORT=8080

# Default command
ENTRYPOINT ["/usr/local/bin/mcp_jujutsu"]
CMD ["--http", "--host=0.0.0.0", "--port=8080"]