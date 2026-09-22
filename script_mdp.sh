#!/bin/bash
set -euo pipefail

echo "====== Running MDP script ======"
echo "====== Setting up dependencies ======"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
VENV_DIR="$SCRIPT_DIR/.venv"
FLAMEGRAPH_DIR="$SCRIPT_DIR/.flamegraph"
PYTHON_BIN="python3.12"
DBG_PYTHON_BIN="python3.12-dbg"
APT_PKGS=()
command -v "$PYTHON_BIN" >/dev/null 2>&1 || APT_PKGS+=(python3.12)
dpkg -s python3.12-venv >/dev/null 2>&1 || APT_PKGS+=(python3.12-venv)
command -v "$DBG_PYTHON_BIN" >/dev/null 2>&1 || APT_PKGS+=(python3.12-dbg)
command -v git >/dev/null 2>&1 || APT_PKGS+=(git)
command -v perf >/dev/null 2>&1 || APT_PKGS+=(linux-tools-common linux-tools-generic "linux-tools-$(uname -r)")
if [ ${#APT_PKGS[@]} -gt 0 ]; then
    echo "Installing missing system packages: ${APT_PKGS[*]}"
    sudo apt-get update
    sudo apt-get install -y "${APT_PKGS[@]}"
fi
if [ ! -d "$FLAMEGRAPH_DIR" ]; then
    echo "Cloning FlameGraph to $FLAMEGRAPH_DIR"
    git clone --depth 1 https://github.com/brendangregg/FlameGraph.git "$FLAMEGRAPH_DIR"
fi
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR"
    if "$PYTHON_BIN" -m venv "$VENV_DIR" 2>/dev/null; then
        :
    else
        echo "ensurepip unavailable, creating venv without pip and bootstrapping it"
        "$PYTHON_BIN" -m venv --without-pip "$VENV_DIR"
        curl -sS https://bootstrap.pypa.io/get-pip.py -o "$SCRIPT_DIR/get-pip.py"
        "$VENV_DIR/bin/python" "$SCRIPT_DIR/get-pip.py" -q
        rm -f "$SCRIPT_DIR/get-pip.py"
    fi
fi
"$VENV_DIR/bin/pip" install --upgrade pip -q
"$VENV_DIR/bin/pip" install pyperformance -q
if command -v "$DBG_PYTHON_BIN" >/dev/null 2>&1; then
    "$DBG_PYTHON_BIN" -m ensurepip --upgrade -q 2>/dev/null || true
    "$DBG_PYTHON_BIN" -m pip install --user --upgrade pip -q
    "$DBG_PYTHON_BIN" -m pip install --user pyperformance -q
fi
DBG_BM_MDP_RUNNER="$("$DBG_PYTHON_BIN" -c "import os, pyperformance; print(os.path.join(os.path.dirname(pyperformance.__file__), 'data-files', 'benchmarks', 'bm_mdp', 'run_benchmark.py'))")"
"$VENV_DIR/bin/python" --version
"$VENV_DIR/bin/python" -m pyperformance --version
source "$VENV_DIR/bin/activate"
export PYTHONPERFSUPPORT=1
echo "====== Environment ready ======"
echo "====== Running MDP benchmark ======"
pyperformance run -b mdp -o mdp_basic_results.json
echo "====== Benchmark results saved to mdp_basic_results.json ======"
echo "====== Generating performance report ======"
sudo -E perf record -F 99 -g --call-graph dwarf -e cpu-clock -- python3.12-dbg -m pyperformance run --bench mdp
sudo perf report --stdio --no-inline > mdp_perf_report_312.txt
echo "====== Performance report saved to mdp_perf_report_312.txt ======"
echo "====== Running MDP benchmark with single worker ======"
sudo -E perf record -F 99 -g --call-graph dwarf -e cpu-clock -o perf_single.data -- python3.12-dbg "$DBG_BM_MDP_RUNNER" --worker -l1 -w1 -n3
sudo perf report -g -i perf_single.data --no-inline > mdp_perf_report_312_single.txt
echo "====== Single worker performance report saved to mdp_perf_report_312_single.txt ======"
sudo perf script -i perf_single.data --no-inline > mdp_single.perf
"$FLAMEGRAPH_DIR/stackcollapse-perf.pl" mdp_single.perf > mdp_single.folded
"$FLAMEGRAPH_DIR/flamegraph.pl" mdp_single.folded > mdp_312_single_flamegraph.svg
echo "====== Single worker flamegraph saved to mdp_312_single_flamegraph.svg ======"
echo "====== Running MDP benchmark with optimized code ======"
pyperformance run --manifest "$SCRIPT_DIR/MANIFEST" -b mdpoptimized -o mdp_optimized_results.json
pyperformance compare mdp_basic_results.json mdp_optimized_results.json
echo "====== Optimized benchmark results saved to mdp_optimized_results.json ======"
echo "====== Generating optimized performance report ======"
sudo -E perf record -F 99 -g --call-graph dwarf -e cpu-clock -- python3.12-dbg -m pyperformance run --manifest "$SCRIPT_DIR/MANIFEST" -b mdpoptimized
sudo perf report --stdio --no-inline > mdp_perf_report_312_opt.txt
echo "====== Optimized performance report saved to mdp_perf_report_312_opt.txt ======"
echo "====== Running MDP script done ======"
