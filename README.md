# ironair

Python multiphysics simulation of rechargeable aqueous alkaline iron-air batteries.

This repository is a **clean Python baseline**. Governing equations come from the
IRONAIR Software Design Requirements Specification (SDRS). Prior MATLAB/Simulink
implementations are not used as a physics source.

## Install

```bash
python3 -m venv venv_iron-air-modeling
source venv_iron-air-modeling/bin/activate
pip install -e ".[dev,notebooks]"
```

UV may be used for the same extras:

```bash
uv venv venv_iron-air-modeling
source venv_iron-air-modeling/bin/activate
uv pip install -e ".[dev,notebooks]"
```

## Public API

```python
import ironair
from ironair import constants
from ironair import chemistry
from ironair import components
from ironair import simulation
from ironair import scenarios
from ironair import plotting
```

## Architecture

Each physical device is a dynamic component with an explicit state vector and

```text
dx/dt = f(t, x, inputs, parameters)
```

Algebraic constitutive laws are solved during RHS evaluation. Instantaneous
electrical resistance is not converted into an artificial lag state.

Shared iron-air chemistry lives in `ironair.chemistry` and is reused by
component models and Jupyter notebooks.

## Requirements

Authoritative requirements are StrictDoc files under `reqs/` (MIL-STD-498
document types, permanent `IA-*` UIDs). Markdown in this README is explanatory
only.

Generated HTML is emitted to `docs/` so GitHub Pages can host it from the `/docs`
folder. `docs/.nojekyll` is included so StrictDoc `_static` assets are served.

```bash
make strictdoc-validate
make strictdoc-generate
```

## Tests are not hardware validation

Passing unit, integration, conservation, and notebook tests verifies the
software against the SDRS. It does not constitute experimental validation of
the physical plant.

Unverified parameters are tagged `unverified_placeholder` or another explicit
`source_class` on `PhysicalParameter` objects.

## Development

```bash
make test
make test-phase-1
make test-phase-2
```
