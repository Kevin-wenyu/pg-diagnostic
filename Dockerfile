# pg - PostgreSQL Diagnostic Tool
# Lightweight container with bash, psql client, and the pg tool

FROM alpine:3.19

# Install bash and PostgreSQL client
RUN apk add --no-cache bash postgresql-client

# Create non-root user
RUN adduser -D -u 1001 pguser

# Copy the pg tool
COPY pg /usr/local/bin/pg
RUN chmod +x /usr/local/bin/pg

# Set working directory
WORKDIR /home/pguser

# Switch to non-root user
USER pguser

# Default command shows help
CMD ["pg", "--help"]
