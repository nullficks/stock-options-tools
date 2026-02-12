# Build stage
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

COPY . .
RUN dart compile js web/main.dart -O4 -o web/main.dart.js

# Runtime stage  
FROM nginx:alpine

COPY --from=build /app/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
