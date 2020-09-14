FROM node:alpine AS build
RUN apk add git

WORKDIR /home/node/app
COPY . .
RUN npm i && npx brunch build --production

FROM nginx:alpine AS runtime
COPY --from=build /home/node/app/public /usr/share/nginx/html