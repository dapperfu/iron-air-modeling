# Architecture

IRONAIR-MATLAB is a pure base-MATLAB, three-fidelity iron-air BESS model.

Hierarchical levels: reaction, electrode, cell, stack, module, enclosure, power block, BESS, and grid.

Dynamic components use `[dx, outputs, diagnostics] = component(t, x, inputs, p)` with named state maps and no global physics state.

Fidelity:

- Level 1: lumped representative cell
- Level 2: grouped volumes and representative strings
- Level 3: 1D finite-volume transport

Resolution presets `smoke`, `standard`, and `reference` change tolerances and mesh counts without source edits.

Authoritative requirements live in `requirements/*.sdoc`. Generated HTML is untracked.
