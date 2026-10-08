"""MathJax-safe siunitx macros for Jupyter notebooks.

Jupyter does not load the real LaTeX ``siunitx`` package. These ``\\newcommand``
definitions emulate siunitx v3 syntax (``\\qty``, ``\\unit``, ``\\si``, ``\\qtyrange``)
so Markdown math cells can write token streams such as
``\\qty{960}{\\milli\\ampere\\hour\\per\\gram}``.

Each unit/prefix macro expands to ``\\mathrm{...}`` (or ``/`` / ``^{2}``) because
MathJax cannot parse a real siunitx unit token stream.

Notebook Markdown and narrative MUST use these macros. Matplotlib/seaborn axis
labels MUST use the Unicode SI strings in ``SI_LABEL`` — matplotlib mathtext does
not expand ``\\qty``.
"""

from __future__ import annotations

from typing import Final

SIUNITX_PREAMBLE: Final[str] = r"""$$
\newcommand{\per}{/}
\newcommand{\squared}{^{2}}
\newcommand{\cubed}{^{3}}
\newcommand{\of}[1]{\,\mathrm{#1}}
\newcommand{\milli}{\mathrm{m}}
\newcommand{\centi}{\mathrm{c}}
\newcommand{\micro}{\mathrm{\mu}}
\newcommand{\kilo}{\mathrm{k}}
\newcommand{\metre}{\mathrm{m}}
\newcommand{\gram}{\mathrm{g}}
\newcommand{\kilogram}{\mathrm{kg}}
\newcommand{\second}{\mathrm{s}}
\newcommand{\minute}{\mathrm{min}}
\newcommand{\hour}{\mathrm{h}}
\newcommand{\day}{\mathrm{d}}
\newcommand{\ampere}{\mathrm{A}}
\newcommand{\volt}{\mathrm{V}}
\newcommand{\watt}{\mathrm{W}}
\newcommand{\ohm}{\mathrm{\Omega}}
\newcommand{\kelvin}{\mathrm{K}}
\newcommand{\celsius}{{}^{\circ}\mathrm{C}}
\newcommand{\coulomb}{\mathrm{C}}
\newcommand{\joule}{\mathrm{J}}
\newcommand{\pascal}{\mathrm{Pa}}
\newcommand{\litre}{\mathrm{L}}
\newcommand{\mole}{\mathrm{mol}}
\newcommand{\molar}{\mathrm{M}}
\newcommand{\percent}{\%}
\newcommand{\atm}{\mathrm{atm}}
\newcommand{\newton}{\mathrm{N}}
\newcommand{\qty}[2]{#1\,#2}
\newcommand{\qtyrange}[3]{#1\text{--}#2\,#3}
\newcommand{\unit}[1]{#1}
\newcommand{\si}[1]{#1}
$$
"""

# Unicode SI strings for seaborn/matplotlib. Do not pass \qty into matplotlib.
SI_LABEL: Final[dict[str, str]] = {
    "t_h": "t (h)",
    "t_min": "t (min)",
    "t_s": "t (s)",
    "t_d": "t (d)",
    "mol": "mol",
    "T_K": "T (K)",
    "mah_g": "mA h g⁻¹",
    "g_cm2": "g cm⁻²",
    "mol_m3": "mol m⁻³",
    "Pa": "Pa",
    "dP_Pa": "ΔP (Pa)",
    "Q_m3_s": "Q (m³/s)",
    "mdot_p": "ṁ (kg s⁻¹) / p (Pa)",
    "W": "W",
    "V": "V",
    "A": "A",
    "M": "M",
    "atm": "atm",
    "mm": "mm",
}


def display_siunitx_preamble() -> None:
    """Show the MathJax siunitx preamble in a running notebook kernel."""
    from IPython.display import Markdown, display

    display(Markdown(SIUNITX_PREAMBLE))
