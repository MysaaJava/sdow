FROM node AS builder

WORKDIR /sdow

COPY website/package.json website/package-lock.json ./
RUN npm ci

COPY website/src ./src
COPY website/public ./public
COPY website/firebase.json ./

RUN npm run build


FROM nginx

WORKDIR /usr/share/nginx/html
COPY --from=builder /sdow/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx_entrypoint.sh /

ENTRYPOINT [ "sh", "/nginx_entrypoint.sh" ]

