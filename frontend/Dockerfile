# Frontend Build Stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm i

# Copy source
COPY . .

# Build application
RUN npm run build

# Production Stage
FROM node:18-alpine

WORKDIR /app

# Install serve to run the application
RUN npm install -g serve

# Copy built application from builder
COPY --from=builder /app/dist ./dist

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:3000 || exit 1

# Serve the application
CMD ["serve", "-s", "dist", "-l", "3000"]
