###############################################################################
# Builder stage: fetch the Opengrep binary and the rules.
# git/curl/ca-certificates live only here and never reach the final image.
###############################################################################
FROM alpine:latest AS builder

# Opengrep release to install: "latest" (default) resolves the newest release
# at build time; pin to a tag (e.g. v1.23.0) to reproduce a specific build.
# See https://github.com/opengrep/opengrep/releases
ARG OPENGREP_VERSION=latest

# git clones the rules, curl/ca-certificates fetch the binary over HTTPS
RUN apk add --no-cache git curl ca-certificates

# Download the static musl Opengrep binary. When OPENGREP_VERSION is "latest",
# resolve the newest tag from the GitHub releases redirect (this avoids the
# rate-limited API and needs no extra tooling like jq).
RUN if [ "$OPENGREP_VERSION" = "latest" ]; then \
        OPENGREP_VERSION="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
            https://github.com/opengrep/opengrep/releases/latest | sed -E 's@.*/tag/@@')"; \
    fi && \
    echo "Installing Opengrep ${OPENGREP_VERSION}" && \
    curl -fsSL -o /usr/local/bin/opengrep \
        "https://github.com/opengrep/opengrep/releases/download/${OPENGREP_VERSION}/opengrep_linux_x86" && \
    chmod +x /usr/local/bin/opengrep && \
    opengrep --version

# Clone the official open-source rules registry
RUN git clone --depth 1 https://github.com/semgrep/semgrep-rules.git /opt/opengrep-rules

# Ensure there will be no problems with rules when launching opengrep scan
RUN rm -rf /opt/opengrep-rules/stats/ \
           /opt/opengrep-rules/.git* \
           /opt/opengrep-rules/.pre-commit-config.yaml \
           /opt/opengrep-rules/template.yaml
RUN find /opt/opengrep-rules \( -name "*.test.yaml" -o -name "*.test.yml" -o -name "*.fixed.test.yaml" \) -delete

###############################################################################
# Final stage: only the Opengrep binary (needs just musl libc) and the rules.
###############################################################################
FROM alpine:latest

RUN apk add --no-cache git

# Copy in just the artifacts built above
COPY --from=builder /usr/local/bin/opengrep /usr/local/bin/opengrep
COPY --from=builder /opt/opengrep-rules /opt/opengrep-rules

# Create and switch to a non-root user for security
RUN adduser -D -u 1000 -h /home/opengrep opengrep
USER opengrep
WORKDIR /src

# Opengrep reads SEMGREP_RULES as the default --config, so users don't have to
# specify the rule path manually
ENV SEMGREP_RULES=/opt/opengrep-rules

# Opengrep has no telemetry; just make sure it never reaches out for version checks
ENV OPENGREP_ENABLE_VERSION_CHECK=false

# Ensure all the included rules are valid
RUN opengrep validate /opt/opengrep-rules
