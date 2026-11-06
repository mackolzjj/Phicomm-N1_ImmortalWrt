#!/bin/bash

# Clone packages
git clone https://github.com/daeuniverse/openwrt-packages --single-branch --depth=1 clone/daepkg
git clone https://github.com/ophub/luci-app-amlogic --single-branch --depth=1 clone/amlogic
git clone https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman --single-branch --depth=1 feeds/luci/applications/luci-app-podman

# Adjust packages (honk replaces dae/passwall; doona UI is embedded in honk)
rm -rf feeds/luci/applications/luci-app-dae feeds/luci/applications/luci-app-daed feeds/luci/applications/luci-app-passwall feeds/packages/net/dae
cp -rf clone/amlogic/luci-app-amlogic feeds/luci/applications/
cp -rf clone/daepkg/luci-app-honk feeds/luci/applications/
cp -rf clone/daepkg/luci-lib-daeuniverse feeds/luci/libs/
cp -rf clone/daepkg/honk clone/daepkg/vmlinux-btf-builtin feeds/packages/net/

# honk's OpenWrt Makefile builds from ./src, so clone the upstream honk source in
# 每次编译自动取 honk 仓库最新 tag（按版本号降序取最新，兼容 beta/rc 预发布）
HONK_TAG=$(git ls-remote --tags --sort="-v:refname" https://github.com/daeuniverse/honk \
  | grep -oE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$' \
  | sed 's#.*/##' | head -1)
echo "本次编译 honk 版本: ${HONK_TAG}"
git clone --recurse-submodules -b "${HONK_TAG}" --depth=1 https://github.com/daeuniverse/honk feeds/packages/net/honk/src
# 同步 Makefile 的 PKG_VERSION，让 opkg 显示的版本号与实际一致（仅匹配标准格式，不匹配则跳过）
sed -i -E "s/^(PKG_VERSION[ :]*=)[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$/\1${HONK_TAG#v}/" feeds/packages/net/honk/Makefile

# ---------------------------------------------------------------------------
# honk needs rustup with its pinned toolchains. The OpenWrt-bundled rust
# (1.96.0) is too old for aya-build@0.2.1 (needs >=1.98), and without rustup
# the rust-toolchain.toml pins (1.99.1 / nightly-2026-10-20) are ignored.
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain 1.99.1 --profile minimal
. "$CARGO_HOME/env"
rustup toolchain install 1.99.1 --profile minimal --component rustfmt clippy
rustup toolchain install nightly-2026-10-20 --profile minimal
rustup component add rust-src llvm-tools --toolchain nightly-2026-10-20
rustup target add bpfel-unknown-none --toolchain nightly-2026-10-20
rustup target add aarch64-unknown-linux-musl --toolchain 1.99.1
# make honk's build.sh prefer rustup's cargo over OpenWrt's bundled rust.
# Insert right after the shebang so it always runs first, regardless of
# whether build.sh uses 'set -eu' / 'set -e' / 'set -uo pipefail'.
sed -i '1a export PATH="$HOME/.cargo/bin:$PATH"' feeds/packages/net/honk/build.sh
# also export for the surrounding Makefile context (defensive)
export PATH="$HOME/.cargo/bin:$PATH"

sed -i '/luci-app-attendedsysupgrade/d' feeds/luci/collections/luci/Makefile

# Clean packages
rm -rf clone
