# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release \
  --dart-define=API_BASE_URL=https://api.orchestrateops.com/v1

# Serve stage
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]