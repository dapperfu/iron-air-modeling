# plant_sim — component-to-plant iron-air simulation

Decade numbering maps patented hardware onto ODE models that an iron-air
engineer can check against US12308414B2 and EP4602674A1.

Chemistry is not re-invented here: stoichiometry, Faraday mapping, Nernst
potentials, and Butler-Volmer kinetics come from `ironair.chemistry`
(IA-SYS-020). Properties of 6 M KOH come from `ironair.properties`.

## How the decades work

| Range | Meaning | Notebooks |
| --- | --- | --- |
| 01-09 | Atomic component ODEs (SSS002) | Iron anode, HER, ORR, OER, GDL, electrolyte, separator, collector, thermal (+ air/hydraulics extras as sections) |
| 10-19 | Half-cell substructures | Negative electrode, air cathode, dual-electrode cell |
| 20-29 | Vessel / stack | Stacked ORR equal ΔP, channeled EP electrode, vessel+lid+DRI |
| 30-39 | Module / BOP | Module, hydraulics, air handling, electrical balance |
| 40-49 | Assembled plant | One `solve_ivp` over concatenated component states |
| 90-99 | Real-world scenarios | Commissioning through multi-day mission |

## How to run

From the repository root, with `src/` and the repo on `PYTHONPATH`:

```bash
python plant_sim/verify_components.py
```

This integrates every component RHS with SciPy BDF/Radau-class stiff solvers,
assembles the plant, runs scenarios 90-99, and writes PNG figures to
`plant_sim/figures/` for review outside a notebook. That export lives in
`plant_sim/plotting.py`, not in `ironair`.

Notebooks in this directory are the source of truth. Edit them directly in
Jupyter (or the IDE). There is no notebook generator. Each notebook imports
the same `plant_sim` physics objects, runs one simulation setup cell, then
gives **each figure its own section** with:

1. a markdown header,
2. **What this plot illustrates** (engineering/patent meaning),
3. **Governing equations** (Jupyter MathJax `$...$` / `$$...$$`),
4. a focused code cell that draws only that figure with seaborn.

Open notebooks from the repo root so `plant_sim` and `ironair` import cleanly,
or run the first bootstrap cell. Format code cells with:

```bash
make format
```

## Units (Jupyter MathJax subset, Unicode on axes)

Jupyter MathJax does **not** load the LaTeX `siunitx` package. Macros such as
`\qty`, `\unit`, `\qtyrange`, and `\molar` are not built-in. A
`$$\newcommand{...}$$` preamble in one cell does not reliably apply to later
markdown cells (each cell is typeset independently).

Write quantities as ordinary `\mathrm{}` SI in `$...$` / `$$...$$`:

- `$6\,\mathrm{M}$` KOH; temperatures in `$\mathrm{K}$`; power in `$\mathrm{W}$`;
  current in `$\mathrm{A}$`; voltage in `$\mathrm{V}$`
- `$960\,\mathrm{mAh\,g^{-1}}$`, `$1\,\mathrm{g\,cm^{-2}}$`, `$\mathrm{A\,m^{-2}}$`
- Ranges: `$3$–$50\,\mathrm{mm}$`

Chemistry stays `\mathrm{Fe(OH)_2}` (not mhchem). Do not use `\begin{align}`,
`\begin{equation}`, or `\(...\)`.

Seaborn/matplotlib labels use Unicode SI (`mA h g⁻¹`, `g cm⁻²`, `mol m⁻³`,
`ΔP (Pa)`). Matplotlib mathtext is a different renderer; keep Unicode on axes.
PNG exports from `plotting.py` follow the same Unicode convention.

## How an engineer verifies against the patents

1. **960 / 320 mA h g⁻¹ Fe** — Faraday capacities in `params.py` must match
   EP4602674A1 [0042]-[0043]. `00_verification_constants.png` bars expected vs
   simulated.
2. **6 M KOH @ 303 K** — default electrolyte and EP FIGS. 19-26 reference;
   US STP is 25 °C / 1 atm (`IA-SYS-021`, `IA-SYS-022`).
3. **Dual electrode** — charge uses OER, discharge uses ORR, ORR isolatable
   (`12_DualElectrodeCell.ipynb`, US Claim 16, EP [0049]).
4. **Stacked ORR equal ΔP** — compensated vs naive pocket thickness
   (`20_CellStack.ipynb`, `96_EqualPressureDropORR.ipynb`, US Claim 1).
5. **EP channel window** — 3-50 mm × 1-40 mm, 10-50 mm spacing, Fe loading
   1-7 g/cm², VF 0.5-0.9 (`21_ChanneledElectrode.ipynb`, `97_ChannelGeometryEP.ipynb`).
6. **Commissioning** — KOH fill, wetting, residual O2, first grid charge, H2/O2,
   T, carbonate, SOC (`90_Commissioning.ipynb`).
7. **LODES thickness** — 8 h / 100 h / 300 h and asymmetric Lc/Ld
   (`91_ChargeDischarge.ipynb`).

Do not copy patent prose into models; cite claim or paragraph numbers only.
