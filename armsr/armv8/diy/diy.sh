#!/bin/bash
# 任何命令失败立即停止，避免错误被后续步骤的 success 掩盖。
# 不加 pipefail：HONK_TAG / ARGON_TAG 管道中 grep 无匹配属正常情况。
set -e

# Clone packages
git clone https://github.com/daeuniverse/openwrt-packages --single-branch --depth=1 clone/daepkg
git clone https://github.com/ophub/luci-app-amlogic --single-branch --depth=1 clone/amlogic
git clone https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman --single-branch --depth=1 feeds/luci/applications/luci-app-podman
# 每次编译自动取 Argon 最新稳定版 tag（三段式版本号，跳过 beta/rc 预发布；
# 与 honk 同用 git ls-remote，无需 token、不受 GitHub API 速率限制）
ARGON_TAG=$(git ls-remote --tags --sort="-v:refname" https://github.com/jerrykuku/luci-theme-argon \
  | grep -oE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sed 's#.*/##' | head -1)
# 网络抖动或上游改命名时回退到已知可用版本，避免单个主题让整次构建失败
ARGON_TAG="${ARGON_TAG:-v3.1.3}"
echo "本次编译 Argon 版本: ${ARGON_TAG}"
git clone -b "${ARGON_TAG}" --depth=1 https://github.com/jerrykuku/luci-theme-argon.git clone/argon

# Adjust packages (honk replaces dae/passwall; doona UI is embedded in honk)
rm -rf feeds/luci/applications/luci-app-dae feeds/luci/applications/luci-app-daed feeds/luci/applications/luci-app-passwall feeds/packages/net/dae

# Argon 3.x integrates the config page into the theme: replace the 2.4.7
# feed package with the latest upstream tag and drop the legacy standalone
# luci-app-argon-config, which would reinstall files now owned by the theme.
# Paths verified against the luci feed pinned by ImmortalWrt v25.12.2:
# theme lives in themes/, the old plugin in applications/.
rm -rf feeds/luci/themes/luci-theme-argon feeds/luci/applications/luci-app-argon-config
cp -rf clone/argon feeds/luci/themes/luci-theme-argon
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
# 1.99.1 已由 rustup-init 装好，这里只补组件（与下方 nightly 同一写法）
rustup component add rustfmt clippy --toolchain 1.99.1
rustup toolchain install nightly-2026-10-20 --profile minimal
rustup component add rust-src llvm-tools --toolchain nightly-2026-10-20
# bpfel-unknown-none 无预编译 std，honk 用 rust-src + -Z build-std 现编，无需 target add
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
