#!/usr/bin/env bash
set -e                                              # stop on first error
cmd=${1:-help}

help() {
  cat <<EOF
Usage: ./run.sh <commande>

  sw        Compile & teste la lib C avec CMake/ctest
  docker    Construit et lance le trio eid/prom/graf
  sim       Compile RTL + lance la simu Icarus
  wave      Ouvre GTKWave sur eid.vcd (si dispo)
  clean     Nettoie artefacts (build/, eid.vcd, conteneurs)
  all       sw + sim + docker
EOF
}

sw() {
  cmake -S . -B build && cmake --build build -j
  (cd build && ctest -V)
}

docker() {
  docker build -t eid-daemon .
  docker rm -f eid prom graf 2>/dev/null || true
  docker run -d --name eid  -p 8000:8000  eid-daemon
  docker run -d --name prom -p 9090:9090 -v "$PWD/prom.yml":/etc/prometheus/prometheus.yml \
             prom/prometheus --config.file=/etc/prometheus/prometheus.yml
  docker run -d --name graf -p 3000:3000 -v "$PWD/graf-data":/var/lib/grafana \
             grafana/grafana-oss
  echo "→ http://localhost:3000  (admin / admin)"
}

sim() {
  iverilog -g2012 -o sim.vvp eid_ctrl.v tb_eid_ctrl.sv
  vvp sim.vvp
}

wave() {
  if command -v gtkwave >/dev/null; then
      gtkwave eid.vcd &
  else
      echo "GTKWave non trouvé."
  fi
}

clean() {
  rm -rf build sim.vvp eid.vcd
  docker rm -f eid prom graf 2>/dev/null || true
}

case $cmd in
  sw)     sw      ;;
  docker) docker ;;
  sim)    sim    ;;
  wave)   wave   ;;
  clean)  clean  ;;
  all)    sw && sim && docker ;;
  *)      help   ;;
esac
