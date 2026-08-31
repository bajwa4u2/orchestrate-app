FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN flutter build web --release \
  --dart-define=API_BASE_URL=https://api.orchestrateops.com/v1

# The Flutter bootstrap names main.dart.js without a content hash. Cloudflare
# can therefore retain an older bundle after a successful Railway deploy.
# Stamp the entrypoint URL at image build time so every public deploy requests
# the bundle belonging to that image while retaining the reproducible source
# build and nginx route structure.
RUN sed -i "s/main.dart.js/main.dart.js?v=$(date +%s)/g" build/web/flutter_bootstrap.js

FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
