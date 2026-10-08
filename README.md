# iron-air-modeling

First-principles continuous-time Simulink library for an aqueous alkaline **iron–air** battery energy storage system.

## Quick start

```powershell
python -m venv .venv
.\.venv\Scripts\pip install strictdoc
matlab -batch "addpath(genpath('.')); lib_IronAir_init; build_lib_IronAir; build_demo_models; results=runtests('tests'); disp(results)"
make strictdoc-generate
```

## Layout

| Path | Role |
|------|------|
| `lib_IronAir.slx` | Masked first-principles library |
| `lib_IronAir_init.m` | Parameters → `lib_IronAir.sldd` |
| `src/` | ODE kernels + Level-2 MATLAB S-Functions |
| `models/` | Cell, stack, 24–100 h plant demos |
| `tests/` | MATLAB unit tests (TD001–TD008) |
| `requirements/` | StrictDoc MIL-STD-498 (SRS…TD) |
| `requirements_html/` | Generated HTML |
| `data/mock/` | Synthetic cell V–I curves |
| `plans/` | Design plan |

## Standards linkage

StrictDoc SRS011–SRS015 plus Simulink blocks `DER_RideThrough_Monitors` and `Standards_Assert_ESS` cover IEEE 1547-2018, IEEE 1547.9-2022, UL 1741, UL 9540, and NFPA 855 behavioral envelopes at plant level (no switching PCS).

## Requirements

- MATLAB R2025b + Simulink
- Python venv with `strictdoc` for requirements HTML
