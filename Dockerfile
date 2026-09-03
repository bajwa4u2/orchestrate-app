FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# --no-tree-shake-icons is deliberate, and costs about a megabyte.
#
# Only main.dart.js is cache-busted below; every other asset, the icon font
# included, is served from a stable URL. With tree-shaking on, that font is a
# SUBSET containing exactly the glyphs of the build that produced it — so a
# stale cached copy is missing any icon added since, and those icons render as
# nothing at all. It is invisible locally, where the font is always fresh, and
# appears only in production. Shipping the whole font makes a stale copy
# harmless.
RUN flutter build web --release --no-tree-shake-icons \
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
