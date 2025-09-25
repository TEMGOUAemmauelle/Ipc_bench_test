FROM ubuntu:22.04
RUN apt-get update && apt-get install -y linux-tools-common linux-tools-generic && rm -rf /var/lib/apt/lists/*
COPY build/source/pipe /app
WORKDIR /app