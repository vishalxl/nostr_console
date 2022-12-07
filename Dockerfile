# file from: https://hub.docker.com/_/dart/

# run using 
#docker build  -t nostr_console .
#docker run -it nostr_console start


# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.12)
FROM dart:stable AS build

RUN apt -y update && apt -y upgrade
# Resolve app dependencies.
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/nostr_console.dart -o bin/nostr_console

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/nostr_console /app/bin/

ENTRYPOINT [ "/app/bin/nostr_console" ]

#CMD [ "yarn" ]
