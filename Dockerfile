FROM nginx:alpine AS runtime
COPY public /usr/share/nginx/html
