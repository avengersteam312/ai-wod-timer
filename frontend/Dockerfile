FROM node:22-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Make entrypoint executable
RUN chmod +x docker-entrypoint.sh

# Expose port
EXPOSE 5173

# Sync packages on startup, then run dev server
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["npm", "run", "dev", "--", "--host"]
