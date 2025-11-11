# Simple production Dockerfile for Core app
FROM nginx:alpine

# Copy custom nginx config
COPY web/core/nginx.conf /etc/nginx/conf.d/default.conf

# Copy pre-built application files
COPY web/core/dist /usr/share/nginx/html

# Fix permissions for nginx user (already exists in nginx:alpine)
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]