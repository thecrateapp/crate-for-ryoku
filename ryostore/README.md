# Ryostore submission

What Crate for Ryoku adds to [Ryostore](https://github.com/Ryoku-dev/ryostore),
ready for a pull request (not sent yet):

- `bundles/crate-for-ryoku/`: the bundle (bundle.json, README, assets, and the
  installer that runs `crate-for-ryoku install`), and its `registry-entry.json`
  for `bundles/registry.json`.
- `plugins/registry-entry.json` and `crate-mark.product-manifest.json`: the
  crate-mark plugin's catalogue entry; its folder is `plugin/crate-mark/` here,
  copied to `plugins/crate-mark/` in Ryostore without the AGENTS.md and
  CLAUDE.md development notes.
- the `crate-desktop-bin` and `crate-for-ryoku` rows for
  `bundles/packages/void.tsv` and `fedora.tsv` (`-`, AUR only).

Before sending: publish `crate-for-ryoku` and `crate-desktop-bin` to the AUR
(the bundle's package items install from there), then in a Ryostore checkout
apply the same changes, run `tools/pack-product.py plugins/crate-mark --touch`,
`tests/validate-catalogue.sh` and `tools/security-screen.py --staged`, and open
the pull request.
