# Builds Petal's web target and serves it with nginx — for a VPS, this is
# the whole deployment: `docker compose up -d --build` from this folder (see
# docker-compose.yml) and point your VPS's reverse proxy / DNS at it.
#
# Stage 1 uses a public Flutter CI image so the VPS itself never needs the
# Flutter SDK installed — only Docker. If this particular image tag is
# unavailable when you build, any image with a working `flutter` on PATH
# works the same way; swap the FROM line.
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN dart run build_runner build --delete-conflicting-outputs
# NOTE: web/ (with the sqlite3.wasm + drift_worker.js assets from the
# README's "Web build setup" step) must already exist in the build context —
# `flutter create . --platforms=web` plus that asset copy needs to have been
# done and committed before this Docker build runs.
RUN flutter build web --release

FROM nginx:alpine AS serve
COPY --from=build /app/build/web /usr/share/nginx/html
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
