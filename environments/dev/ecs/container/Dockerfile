FROM nginx:1.30.6

RUN apt-get update \
    && apt-get install -y --no-install-recommends stress-ng \
    && rm -rf /var/lib/apt/lists/*
