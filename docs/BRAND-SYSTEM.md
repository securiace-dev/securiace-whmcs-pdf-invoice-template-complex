# Securiace brand system

Canonical tokens for the unified WHMCS child theme, browser previews, and
print-safe PDF documents. Source of truth: `assets/brand/tokens.json` and
`assets/brand/tokens.css`.

## Core palette

| Token | Hex | Role |
| --- | --- | --- |
| Midnight Navy | `#0B1324` | Dark canvas; light-mode ink; PDF header band |
| Electric Cyan | `#00E6FF` | Accents, focus, PDF header rule |
| Teal Blue | `#008DBA` | Primary brand fill / light-mode accent |
| Ice White | `#F4F7FB` | Light canvas; dark-mode text; PDF paper |

## Dark / light client area

One System Theme (`securiace`) carries both modes via `data-theme` on `<html>`.

Resolution order:

1. Explicit user choice in `localStorage` key `securiace-theme-mode`
2. Else `prefers-color-scheme`
3. Else **dark** (primary digital brand)

Toggle UI is injected by `templates/securiace/js/custom.js`. Early flash
prevention is provided by `hooks/securiace-theme-mode.php`.

### Semantic mapping

| Token | Dark | Light |
| --- | --- | --- |
| `--bg-canvas` | `#0B1324` | `#F4F7FB` |
| `--bg-surface` | `#121C31` | `#FFFFFF` |
| `--fg-primary` | `#F4F7FB` | `#0B1324` |
| `--fg-muted` | `#8BA0B8` | `#5A6B7D` |
| `--accent` | `#00E6FF` | `#008DBA` |
| `--accent-strong` | `#00E6FF` | `#00E6FF` |
| `--border` | `#1E3A4F` | `#C9D4E0` |

Rules:

- Keep cyan as the high-signal accent; do not introduce purple/pastel substitutes.
- Prefer geometric spacing and sharp corners over soft consumer UI chrome.
- Use on-dark logos in dark mode and on-light / mono-navy logos in light mode.
- Avoid cyan-on-cyan and ice-on-ice pairings without contrast checks.

## PDF surface (print hybrid)

PDFs do **not** follow client dark/light mode. They always use:

- Midnight Navy header band with cyan accent rule
- Ice White body/tables
- Teal brand labels and status soft fills
- WHMCS `assets/img/logo.png` when present (install from `assets/brand/logo.png`)

This preserves ink, email, and statutory readability while carrying brand DNA in
the header.

TCPDF RGB contract (must stay synchronized with templates):

- Brand / teal: `0, 141, 186`
- Accent / cyan: `0, 230, 255`
- Navy / ink / header: `11, 19, 36`
- Paper / ice: `244, 247, 251`

## Logo inventory

| File | Use |
| --- | --- |
| `assets/brand/logo-primary.svg` / `.png` | Horizontal lockup on light |
| `assets/brand/logo-primary-on-dark.svg` / `.png` | Horizontal lockup on navy |
| `assets/brand/logo-stacked.svg` | Centered stacked lockup |
| `assets/brand/logo-icon.svg` / `.png` | Favicon / compact mark |
| `assets/brand/logo-avatar.svg` / `.png` | Social avatar |
| `assets/brand/logo-mono-*.svg` | Single-color marks |
| `assets/brand/logo.png` | Copy to `WHMCS_ROOT/assets/img/logo.png` |

Theme-local copies for CSS live under `templates/securiace/img/`.

## Typography

- UI display: Exo 2 / Orbitron / Montserrat stack (web-safe fallbacks)
- PDF body: WHMCS configured `TCPDFFont` only (no custom font binaries in v1)
