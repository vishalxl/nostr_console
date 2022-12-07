# file from: https://hub.docker.com/_/dart/

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


# build nostr-terminal and invoke it
FROM node:16

WORKDIR /nostr-terminal
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" |  tee /etc/apt/sources.list.d/yarn.list

RUN  apt update -y &&  apt install -y yarn
RUN npm install node-pty dotenv

# https://stackoverflow.com/questions/38905135/why-wont-my-docker-entrypoint-sh-execute
RUN git config --global core.autocrlf input 


RUN git clone https://github.com/vishalxl/nostr-terminal.git  

COPY --from=build /app/bin/nostr_console /nostr-terminal/
RUN echo "/nostr-terminal/nostr_console  --width=120 --align=left" >> /nostr-terminal/console.sh 
RUN PATH=$PATH:/nostr-terminal/
#RUN chmod 755 /nostr-terminal/nostr_console 
WORKDIR /nostr-terminal/nostr-terminal
RUN npm install 
#ENTRYPOINT ["/nostr-terminal/nostr_console"]
ENTRYPOINT [ "yarn" ]

#CMD [ "yarn" ]
