# Base Ubuntu 22.04 (pour glibc 2.35)
FROM ubuntu:22.04

# Éviter les interactions pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libzmq3-dev \
    && rm -rf /var/lib/apt/lists/*

# Copier le code source
WORKDIR /app
COPY . .



# Créer un script pour lancer le benchmark
RUN echo '#!/bin/bash\n\
echo "Lancement du benchmark mmap (mémoire partagée)"\n\
cd build/source/fifo && ./fifo -c 1000 -s 100\n\
' > /app/run_bench.sh && chmod +x /app/run_bench.sh

# S'assurer que l'utilisateur est root
USER root

# Lancer le script
CMD ["/app/run_bench.sh"]