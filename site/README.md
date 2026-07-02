# One More Cap Site

This folder contains the self-contained Press static site for One More Cap.

The site is deployed from this repository, not from a separate Pages repository.
Runtime files are vendored from `EkilyHQ/YAP`, which is the starter template for
Press sites. The default installed theme is `Arcus` from
`EkilyHQ/Press-Theme-Arcus`, pinned in `assets/themes/packs.json`.
App-specific content lives under `wwwroot/`.

Key pages:

- `wwwroot/tab/home/`
- `wwwroot/tab/privacy/`
- `wwwroot/tab/support/`

The App Store submission can use the published Privacy Policy and Support page
URLs from this site. The site hides the article list with `showAllPosts: false`
and uses `landingTab: Home`.

The repository keeps the Press/YAP editor files so the site remains
self-contained, but `scripts/build-site.sh` does not publish the editor
entrypoint HTML files in the GitHub Pages artifact.

Build the Pages artifact locally with:

```sh
scripts/build-site.sh
```
