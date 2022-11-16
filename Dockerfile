# file from: https://hub.docker.com/_/dart/

# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS build

RUN apt -y update && apt -y upgrade
# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

# Copy app source code and AOT compile it.
COPY . .
# Ensure packages are still up-to-date if anything has changed
RUN dart pub get --offline
RUN dart compile exe bin/helloworld.dart -o bin/helloworld

# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/helloworld /app/bin/


CMD ["/app/bin/helloworld"]

# CMD ["dart run /app/bin/nostr_console.dart "]
