# Bench-flexran

## Purpose
Scripts and configuration to run the FlexRAN (Flexible Radio Access Network) benchmark within the crucible framework. Tests baseband processing performance for 4G/5G workloads.

## Languages
- Bash: wrapper scripts (flexran-base, flexran-client, flexran-server-start/stop, flexran-infra, flexran-setup-env)
- Python: test automation and post-processing (autotest.py, cpu.py, process_testfile.py, flexran-post-process)

## Key Files
| File | Purpose |
|------|---------|
| `rickshaw.json` | Rickshaw integration: client/server/infra scripts, parameter transformations |
| `flexran-base` | Base setup shared by other scripts |
| `flexran-client` | Client-side benchmark execution |
| `flexran-server-start` / `flexran-server-stop` | Server lifecycle management |
| `flexran-infra` | Infrastructure setup |
| `flexran-setup-env` | Environment configuration |
| `flexran-post-process` | Parses flexran output into crucible metrics |
| `autotest.py` | Test automation driver |
| `workshop.json` | Engine image build requirements |

## Conventions
- Primary branch is `main`
- Standard Bash modelines and 4-space indentation
