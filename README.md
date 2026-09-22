# hwswcodesign_project

This repo is the project for HW/SW Co-design course @Technion,
Profiling and optimizing **MDP** and **GO** pyperformance benchmarks.

## Directory structure

```
.
├── script_go.sh              # Runs the full GO benchmark/profiling pipeline
├── script_mdp.sh             # Runs the full MDP benchmark/profiling pipeline
├── MANIFEST                  # pyperformance manifest declaring the custom "gooptimized" / "mdpoptimized" benchmarks
├── bm_gooptimized/            # pyperformance package for the optimized GO benchmark
│   ├── pyproject.toml
│   └── run_benchmark.py
├── bm_mdpoptimized/           # pyperformance package for the optimized MDP benchmark
│   ├── pyproject.toml
│   └── run_benchmark.py
├── go/                        # GO workload source + generated results
│   ├── go_run_benchmark.py        # baseline implementation
│   ├── go_optimized.py            # optimized implementation
│   ├── go_basic_results.json      # pyperformance results, baseline
│   ├── go_optimized_results.json  # pyperformance results, optimized
│   ├── go_perf_report_312*.txt    # `perf report` output (full run / single worker)
│   └── go_312_single_flamegraph.svg
├── mdp/                       # MDP workload source + generated results
│   ├── mdp_run_benchmark.py       # baseline implementation
│   ├── mdp_optimized.py           # optimized implementation
│   ├── mdp_hw_accelerator.sv      # SystemVerilog HW accelerator for MDP
│   ├── mdp_basic_results.json
│   ├── mdp_optimized_results.json
│   ├── mdp_perf_report_312*.txt
│   └── mdp_312_single_flamegraph.svg
├── report_go.pdf             # Written report for the GO workload
├── report_mdp.pdf            # Written report for the MDP workload
└── prompt.pdf                # Original assignment prompt
```

## Running the scripts

Each script is self-contained and can be run from any directory (it `cd`s
into its own location first):

```bash
./script_go.sh    # GO workload
./script_mdp.sh   # MDP workload
```

Each run will:

1. Install missing system packages (`python3.12`, `python3.12-venv`,
   `python3.12-dbg`, `git`, `perf`) if needed.
2. Clone FlameGraph into `.flamegraph/` if not already present.
3. Create/reuse a local `.venv` and install `pyperformance` into it, plus
   install `pyperformance` for the system `python3.12-dbg` interpreter
   (needed since it's invoked directly under `perf record`).
4. Run the baseline pyperformance benchmark (`go` / `mdp`) and save results
   to `go_basic_results.json` / `mdp_basic_results.json`.
5. Record and report a full `perf` profile of the baseline run
   (`*_perf_report_312.txt`).
6. Record a single-worker `perf` profile, generate a text report
   (`*_perf_report_312_single.txt`) and a flamegraph SVG
   (`*_312_single_flamegraph.svg`).
7. Run the optimized benchmark (`goOptimized` / `mdpOptimized`, defined in
   `MANIFEST` + `bm_gooptimized`/`bm_mdpoptimized`), save its results, and
   print a `pyperformance compare` summary against the baseline.
8. Record and report a `perf` profile of the optimized run.

All output files land in the directory you ran the script from (`.` at the
repo root — the JSON/`.txt`/`.svg` files already checked into `go/` and
`mdp/` are the results of prior runs, kept for reference).
