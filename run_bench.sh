#!/bin/bash

# Configuration
ENGINE=${1:-docker}  # docker par défaut, ou passez 'crio' ou 'podman'
TIMEOUT=30
RESULTS_FILE="bench_results_$(date +%Y%m%d_%H%M%S).txt"
SIZES=(1024 2048 4096 5120 6144 7168 10240 15360 20480 25600 30720 35840 40960)  # 1K, 2K, ..., 40K en octets

# Fonction pour exécuter le benchmark et mesurer IPC
run_bench() {
    local size=$1
    local mode=$2  # "host" ou "container"
    echo "=== Pipe -s $size ($mode, $ENGINE) ===" | tee -a $RESULTS_FILE

    if [ "$mode" = "host" ]; then
        perf stat -e cycles,instructions ./build/source/pipe/pipe -c 200000 -s $size 2>&1 | tee -a $RESULTS_FILE
        ipc=$(awk '/instructions/ {i=$1} /cycles/ {c=$1} END {if (c>0) print i/c; else print "N/A"}' $RESULTS_FILE | tail -1)
        echo "IPC (host): $ipc" | tee -a $RESULTS_FILE
    else
        # Build image si non existante
        if [ ! -f Dockerfile ]; then
            cat > Dockerfile << EOF
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y linux-tools-common linux-tools-generic && rm -rf /var/lib/apt/lists/*
COPY build/source/pipe /app
WORKDIR /app
EOF
            $ENGINE build -t pipe-bench .
        fi

        case $ENGINE in
            docker)
                docker run --rm --privileged -v $(pwd)/build/source/pipe:/app pipe-bench perf stat -e cycles,instructions ./pipe -c 200000 -s $size 2>&1 | tee -a $RESULTS_FILE
                ;;
            podman)
                podman run --rm --privileged -v $(pwd)/build/source/pipe:/app pipe-bench perf stat -e cycles,instructions ./pipe -c 200000 -s $size 2>&1 | tee -a $RESULTS_FILE
                ;;
            crio)
                # Pod spec simplifié pour crictl (adaptez si nécessaire)
                cat > pod.json << EOF
{
  "metadata": { "name": "pipe-bench" },
  "containers": [{
    "image": { "image": "pipe-bench" },
    "command": ["perf", "stat", "-e", "cycles,instructions", "./pipe", "-c", "200000", "-s", "$size"],
    "working_dir": "/app",
    "linux": { "privileged": true }
  }]
}
EOF
                crictl runp pod.json
                sleep $TIMEOUT && crictl stop $(crictl ps -q) && crictl rm $(crictl ps -q)
                crictl logs $(crictl ps -q) >> $RESULTS_FILE 2>&1
                ;;
        esac
        ipc=$(awk '/instructions/ {i=$1} /cycles/ {c=$1} END {if (c>0) print i/c; else print "N/A"}' $RESULTS_FILE | tail -1)
        echo "IPC ($ENGINE): $ipc" | tee -a $RESULTS_FILE
    fi
    echo "" | tee -a $RESULTS_FILE
}

# Exécution
for size in "${SIZES[@]}"; do
    run_bench $size "host"
    run_bench $size "container"
done

echo "Résultats dans $RESULTS_FILE"