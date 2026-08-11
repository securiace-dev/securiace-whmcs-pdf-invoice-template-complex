# Unified theme repository — clone instructions

The unified Securiace WHMCS theme lives on GitHub **now** (72 files). A
separate org repo `securiace-dev/securiace-whmcs-theme` is created from your
Mac with `gh repo create` — the cloud agent cannot do that (403).

## Clone to your Mac (works today)

```bash
git clone -b securiace-whmcs-theme --single-branch \
  https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex.git \
  ~/securiace-whmcs-theme

cd ~/securiace-whmcs-theme
git log --oneline -3
ls templates/securiace/
```

Browse on GitHub:

https://github.com/securiace-dev/securiace-whmcs-pdf-invoice-template-complex/tree/securiace-whmcs-theme

Tag: `securiace-whmcs-theme-v1`

## Create the canonical org repo (Mac only)

```bash
cd ~/securiace-whmcs-theme
bash ./scripts/publish-to-github.sh
```

Or full bootstrap (clone + publish + tests):

```bash
bash ./scripts/local-bootstrap.sh ~/securiace-whmcs-theme
```

Use **`bash`** — nushell cannot run `.sh` files directly.

## What is on this branch

- `templates/securiace/` child theme (dark/light, brand tokens)
- `invoicepdf-modern.tpl`, `quotepdf-modern.tpl`, previews
- `assets/brand/`, hooks, addon, tests, CI, docs

Latest commit at time of writing: see GitHub branch tip.
