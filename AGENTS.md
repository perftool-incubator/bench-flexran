# Bench-flexran

## Purpose
Scripts and configuration to run the FlexRAN (Flexible Radio Access Network) benchmark within the crucible framework. Tests baseband processing performance for 4G/5G workloads.

## Languages
- Bash: wrapper scripts (`flexran-base`, `flexran-client`, `flexran-server-start`/`stop`, `flexran-infra`, `flexran-setup-env`, `flexran-runtime`, `driver.sh`)
- Python: test automation and post-processing (`autotest.py`, `cpu.py`, `log.py`, `process_testfile.py`, `flexran-post-process.py`)

## Key Files
| File | Purpose |
|------|---------|
| `rickshaw.json` | Rickshaw integration: client/server/infra scripts, parameter transformations |
| `multiplex.json` | Parameter validation rules, unit conversions, and presets for multiplex |
| `benchmark-metadata.json` | Machine-readable description and CDM-indexed source/type list (consumed by `crucible benchmarks list`) |
| `flexran-base` | Base setup shared by other scripts |
| `flexran-client` | Client-side benchmark execution |
| `flexran-server-start` / `flexran-server-stop` | Server lifecycle management |
| `flexran-infra` | Infrastructure setup |
| `flexran-setup-env` | Environment configuration (pre-script) |
| `flexran-runtime` | Extracts runtime from command-line options |
| `flexran-post-process.py` | Parses flexran output into crucible metrics |
| `autotest.py` | Test automation driver |
| `workshop.json` | Engine image build requirements |

## Conventions
- Primary branch is `main`
- Standard Bash modelines and 4-space indentation
- Python code follows 4-space indentation with standard modelines
