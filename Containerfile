# This stage is responsible for holding onto
# your config without copying it directly into
# the final image
FROM scratch AS stage-files
COPY ./files /files

# Copy modules
# The default modules are inside blue-build/modules
# Custom modules overwrite defaults
FROM scratch AS stage-modules
COPY ./modules /modules

# Bins to install
# These are basic tools that are added to all images.
# Generally used for the build process. We use a multi
# stage process so that adding the bins into the image
# can be added to the ostree commits.
FROM scratch AS stage-bins
COPY --from=ghcr.io/sigstore/cosign/cosign:v2.5.3 /ko-app/cosign /bins/cosign
COPY --from=ghcr.io/blue-build/cli:latest-installer \
  /out/bluebuild /bins/bluebuild
# Keys for pre-verified images
# Used to copy the keys into the final image
# and perform an ostree commit.
#
# Currently only holds the current image's
# public key.
FROM scratch AS stage-keys
COPY cosign.pub /keys/custom-image.pub

# Stage for AKmod main
FROM scratch as stage-akmods-main
COPY --from=ghcr.io/ublue-os/akmods:main-42 /rpms /rpms

# Main image
FROM ghcr.io/ublue-os/aurora-dx@sha256:602b852af73829513df520779a25341ab90e49c032cb77a24e0da8da127f9fa8 AS custom-image
ARG RECIPE=recipes/recipe.yml
ARG IMAGE_REGISTRY=localhost
ARG CONFIG_DIRECTORY="/tmp/files"
ARG MODULE_DIRECTORY="/tmp/modules"
ARG IMAGE_NAME="custom-image"
ARG BASE_IMAGE="ghcr.io/ublue-os/aurora-dx"
ARG FORCE_COLOR=1
ARG CLICOLOR_FORCE=1
ARG RUST_LOG_STYLE=always
# Key RUN
RUN --mount=type=bind,from=stage-keys,src=/keys,dst=/tmp/keys \
  mkdir -p /etc/pki/containers/ \
  && cp /tmp/keys/* /etc/pki/containers/

# Bin RUN
RUN --mount=type=bind,from=stage-bins,src=/bins,dst=/tmp/bins \
  mkdir -p /usr/bin/ \
  && cp /tmp/bins/* /usr/bin/
RUN --mount=type=bind,from=ghcr.io/blue-build/nushell-image:default,src=/nu,dst=/tmp/nu \
  mkdir -p /usr/libexec/bluebuild/nu \
  && cp -r /tmp/nu/* /usr/libexec/bluebuild/nu/
RUN --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/scripts/ \
  /scripts/pre_build.sh

# Module RUNs
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/script:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'script' '{"type":"script","scripts":["add_codium_repo.sh"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/dnf:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'dnf' '{"type":"dnf","repos":{"copr":{"enable":["sneexy/zen-browser"]}},"install":{"packages":["zen-browser","micro","codium"]},"remove":{"packages":["code"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/files:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'files' '{"type":"files","files":[{"source":"system","destination":"/"}]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/default-flatpaks:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'default-flatpaks' '{"type":"default-flatpaks","notify":true,"system":{"install":["io.github.dvlv.boxbuddyrs","io.github.flattool.Warehouse","org.gimp.GIMP","org.kde.gwenview","org.kde.kdenlive","org.kde.krita","org.kde.haruna","org.kde.kcalc","org.kde.okular","org.libreoffice.LibreOffice"]},"user":{}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/signing:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'signing' '{"type":"signing"}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/systemd:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'systemd' '{"type":"systemd","system":{"disabled":["ModemManager.service","systemd-homed.service","systemd-machined.service","zfs-zed.service"]}}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/akmods:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=stage-akmods-main,src=/rpms,dst=/tmp/rpms,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'akmods' '{"type":"akmods","install":["evdi"]}'
RUN \
--mount=type=bind,from=stage-files,src=/files,dst=/tmp/files,rw \
--mount=type=bind,from=ghcr.io/blue-build/modules/dnf:latest,src=/modules,dst=/tmp/modules,rw \
--mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/tmp/scripts/ \
  --mount=type=cache,dst=/var/cache/rpm-ostree,id=rpm-ostree-cache-custom-image-stable,sharing=locked \
  --mount=type=cache,dst=/var/cache/libdnf5,id=dnf-cache-custom-image-stable,sharing=locked \
/tmp/scripts/run_module.sh 'dnf' '{"type":"dnf","install":{"packages":["displaylink"]}}'

RUN --mount=type=bind,from=ghcr.io/blue-build/cli/build-scripts:ef0d731664a182a89451bba178a539fb559a2c6b,src=/scripts/,dst=/scripts/ \
  /scripts/post_build.sh

# Labels are added last since they cause cache misses with buildah
LABEL org.blue-build.build-id="ebb6897b-cc65-4fc4-95be-2caa74dc0aa7"
LABEL org.opencontainers.image.title="custom-image"
LABEL org.opencontainers.image.description="Custom Aurora image"
LABEL org.opencontainers.image.source=""
LABEL org.opencontainers.image.base.digest="sha256:602b852af73829513df520779a25341ab90e49c032cb77a24e0da8da127f9fa8"
LABEL org.opencontainers.image.base.name="ghcr.io/ublue-os/aurora-dx:stable"
LABEL org.opencontainers.image.created="2025-07-21T18:29:51.436214486+00:00"
LABEL io.artifacthub.package.readme-url=https://raw.githubusercontent.com/blue-build/cli/main/README.md