#!/usr/bin/env bash
set -euo pipefail
language="${1:?language}"

apt_install() {
  apt-get update
  apt-get install -y --no-install-recommends "$@"
}

archive() {
  local url="$1" destination="$2"
  mkdir -p "$destination"
  curl --fail --location --retry 3 "$url" -o /tmp/toolchain.archive
  tar -xf /tmp/toolchain.archive -C "$destination" --strip-components=1
  rm /tmp/toolchain.archive
}

rust() {
  curl --fail --location --retry 3 https://sh.rustup.rs -o /tmp/rustup.sh
  bash /tmp/rustup.sh -y --profile minimal --default-toolchain stable
}

case "$language" in
  acton)
    archive https://github.com/actonlang/acton/releases/download/tip/acton-linux-x86_64-tip.tar.xz /opt/acton
    chown -R "$BENCH_UID" /opt/acton
    ln -s /opt/acton/bin/acton /usr/local/bin/acton
    ;;
  c|cpp|chapel|dart|elixir|go|hacklang|java|kotlin|python|swift)
    ;;
  codon)
    curl --fail --location --retry 3 https://exaloop.io/install.sh -o /tmp/codon.sh
    bash /tmp/codon.sh
    ;;
  crystal)
    apt_install crystal shards libpcre2-dev
    ;;
  csharp)
    curl --fail --location --retry 3 https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o /tmp/microsoft.deb
    dpkg -i /tmp/microsoft.deb
    apt_install libmsquic
    dotnet dev-certs https
    ;;
  d)
    apt_install ldc dub
    ;;
  fortran)
    apt_install gfortran
    ;;
  hare)
    apt_install scdoc
    git clone --depth 1 https://git.sr.ht/~mpu/qbe /tmp/qbe
    make -C /tmp/qbe -j2
    make -C /tmp/qbe install PREFIX=/usr/local
    git clone --depth 1 https://git.sr.ht/~sircmpwn/harec /tmp/harec
    cp /tmp/harec/configs/linux.mk /tmp/harec/config.mk
    make -C /tmp/harec -j2
    make -C /tmp/harec install PREFIX=/usr/local
    git clone --depth 1 https://git.sr.ht/~sircmpwn/hare /tmp/hare
    cp /tmp/hare/configs/linux.mk /tmp/hare/config.mk
    make -C /tmp/hare -j2
    make -C /tmp/hare install PREFIX=/usr/local
    ;;
  haskell)
    apt_install ghc cabal-install
    ;;
  haxe)
    apt_install haxe
    mkdir -p "$HOME/haxelib"
    haxelib setup "$HOME/haxelib"
    haxelib install hxcpp --quiet
    ;;
  javascript)
    curl --fail --location --retry 3 https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64-baseline.zip -o /tmp/bun.zip
    unzip /tmp/bun.zip -d /tmp/bun
    install /tmp/bun/bun-linux-x64-baseline/bun /usr/local/bin/bun
    ;;
  julia)
    julia -e 'using Pkg; Pkg.add(["JSON", "MD5"])'
    ;;
  lisp)
    apt_install sbcl
    ;;
  lua)
    apt_install lua5.4 luajit
    ;;
  nelua)
    git clone --depth 1 https://github.com/edubart/nelua-lang.git /opt/nelua
    make -C /opt/nelua -j2
    make -C /opt/nelua install
    ;;
  nim)
    apt_install libpcre3
    archive https://nim-lang.org/download/nim-2.2.4-linux_x64.tar.xz /opt/nim
    ln -s /opt/nim/bin/nim /usr/local/bin/nim
    ln -s /opt/nim/bin/nimble /usr/local/bin/nimble
    ;;
  ocaml)
    apt_install opam
    opam init --disable-sandboxing --bare -y
    opam switch create 5.3.0 -y
    echo 'eval "$(opam env --switch=5.3.0 --set-switch)"' >> "$PROFILE"
    ;;
  odin)
    curl --fail --location --retry 3 https://github.com/odin-lang/Odin/releases/download/dev-2024-11/odin-linux-amd64-dev-2024-11.zip -o /tmp/odin.zip
    mkdir /opt/odin
    unzip /tmp/odin.zip -d /opt/odin
    cd /opt/odin
    tar -xf dist.tar.gz
    find /opt/odin -type f -name odin -executable -exec ln -s '{}' /usr/local/bin/odin \;
    ;;
  perl)
    apt_install perl libmath-bigint-gmp-perl
    ;;
  php)
    apt_install php-cli php-gmp
    ;;
  pony)
    curl --fail --location --retry 3 https://raw.githubusercontent.com/ponylang/ponyup/latest-release/ponyup-init.sh -o /tmp/ponyup.sh
    sh /tmp/ponyup.sh
    ponyup update ponyc release
    ponyup update corral release
    ;;
  racket)
    apt_install racket
    ;;
  ruby)
    apt_install ruby ruby-dev
    gem install gmp --no-document
    ;;
  rust)
    rust
    ;;
  typescript)
    curl --fail --location --retry 3 https://deno.land/install.sh -o /tmp/deno.sh
    bash /tmp/deno.sh
    ;;
  v)
    git clone --depth 1 https://github.com/vlang/v /opt/vlang
    make -C /opt/vlang -j2
    ln -s /opt/vlang/v /usr/local/bin/v
    ;;
  wasm)
    rust
    rustup target add wasm32-wasip1
    archive https://github.com/bytecodealliance/wasmtime/releases/download/v48.0.2/wasmtime-v48.0.2-x86_64-linux.tar.xz /opt/wasmtime
    ln -s /opt/wasmtime/wasmtime /usr/local/bin/wasmtime
    ;;
  wren)
    git clone --depth 1 --recurse-submodules https://github.com/wren-lang/wren-cli /opt/wren-cli
    make -C /opt/wren-cli/projects/make -j2
    install /opt/wren-cli/bin/wren_cli /usr/local/bin/wren_cli
    ;;
  zig)
    archive https://ziglang.org/download/0.14.1/zig-x86_64-linux-0.14.1.tar.xz /opt/zig
    ln -s /opt/zig/zig /usr/local/bin/zig
    ;;
  *) echo "Unknown language: $language" >&2; exit 1 ;;
esac
