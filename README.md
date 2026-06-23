# opengrep-bundle
Repository to prepare and publish an opengrep image with the public ruleset.

The image is published to this URL: `ghcr.io/nicovell3/opengrep-bundle:latest`

The unique requirement is to include the repository to analyze in the `/src` path.

Example usage:

```
docker run --rm \
  -v "$(pwd)/my/code/to/analyze:/src" \
  ghcr.io/nicovell3/opengrep-bundled:latest \
  opengrep scan
```

