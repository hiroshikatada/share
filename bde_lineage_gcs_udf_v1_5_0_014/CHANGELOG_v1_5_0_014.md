# v1.5.0-014

## Issue-0100-4 Performance Regression

- Added a reproducible Node.js performance regression harness.
- Added warm-up iterations so JIT startup cost is excluded from measured results.
- Added representative Basic, Complex, Deep Nested and Production workloads.
- Added median and p95 latency measurements for each workload.
- Added p95/median stability-ratio validation to detect highly unstable runs.
- Added per-analysis heap-delta monitoring.
- Added full 46-case suite throughput and average-latency validation.
- Added a versioned performance contract in `test/performance_contract_v1_5_0_014.json`.
- No LineageEngine source change was required.
