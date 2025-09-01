# Borealis &nbsp; [![bluebuild build badge](https://github.com/japsert123/custom-image/actions/workflows/build.yml/badge.svg)](https://github.com/japsert123/custom-image/actions/workflows/build.yml)

This is a custom bootc image based on Universal Blue's [Aurora-DX](https://getaurora.dev/en), this repository generates two images: 1 with Nvidia-open drivers and 1 without. The changes made are as follows:
- Replace VSCode with VSCodium
- Install DisplayLink from the [COPR Repository](https://copr.fedorainfracloud.org/coprs/crashdummy/Displaylink/) and enable the Systemd service
- Install the Vivaldi and Zen browser as native packages instead of Flatpaks for [increased security](https://discussion.fedoraproject.org/t/is-it-better-to-have-a-browser-sand-boxed-with-flatpak-or-not/162425/17).
- Install the Micro text editor
- Pre-install [a number](https://github.com/Japsert123/custom-image/blob/37558df5f272bedf3aae0b2286a7e93eef56062d/recipes/pkg.yml#L37C9-L37C16) of flatpaks

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  sudo bootc switch ghcr.io/japsert123/borealis:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  sudo bootc switch --enforce-container-sigpolicy ghcr.io/japsert123/borealis:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```
  
## Building locally
Building locally is most easily done in distrobox. Clone this repo and run the following command:

```bash
distrobox-assemble create
```
This will download the BlueBuid distrobox image and export the ```bluebuild``` binary. The images can be built with 

```bash
bluebuild build recipes/recipe.yml
```
or

```bash
bluebuild build recipes/nv.yml
```

It is also possible to generate a ```Containerfile``` with BlueBuild, see the [docs](https://blue-build.org/how-to/local/) for more information. 

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/japsert123/borealis
```
