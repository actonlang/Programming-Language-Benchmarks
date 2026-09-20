ARG TOOLCHAIN_IMAGE=mcr.microsoft.com/dotnet/sdk:9.0-noble
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble AS dotnet
FROM ${TOOLCHAIN_IMAGE}
USER root
ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_ROOT=/opt/dotnet \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    HOME=/opt/bench-home \
    PROFILE=/opt/bench-profile \
    GOTOOLCHAIN=local \
    PYTHONINTMAXSTRDIGITS=0 \
    MIX_ENV=prod
COPY --from=dotnet /usr/share/dotnet /opt/dotnet
ENV PATH=/opt/dotnet:/opt/bench-home/.cargo/bin:/opt/bench-home/.nimble/bin:/opt/bench-home/.bun/bin:/opt/bench-home/.deno/bin:/opt/bench-home/.wasmtime/bin:/opt/bench-home/.codon/bin:${PATH}
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash build-essential ca-certificates clang cmake curl file git jq \
    libgc-dev libgmp-dev libicu-dev libomp-dev libssl-dev libunwind-dev \
    libuv1-dev pkg-config procps python3 python3-pip python3-yaml \
    sudo tar unzip xz-utils zlib1g-dev \
    && mkdir -p /opt/bench-home && touch /opt/bench-profile \
    && chmod 1777 /opt/bench-home \
    && echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/benchmark \
    && chmod 440 /etc/sudoers.d/benchmark
ARG LANGUAGE
ARG BENCH_UID=1000
LABEL org.actonlang.benchmarks=true
COPY setup-language.sh /opt/setup-language.sh
RUN bash /opt/setup-language.sh "$LANGUAGE" \
    && (getent passwd "$BENCH_UID" || useradd --uid "$BENCH_UID" --home-dir /opt/bench-home --no-create-home benchmark) \
    && chown -R "$BENCH_UID" /opt/bench-home \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /work
ENTRYPOINT []
CMD []
