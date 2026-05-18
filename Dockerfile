FROM debian:trixie-slim as build
ENV DEBIAN_FRONTEND noninteractive

# --------------------------------------------------
# Downloaded file hashes
# --------------------------------------------------
ARG OTP_SHA256HASH=032b64b0de42bf66a13086bf18b8e62a5d83dcf32ac0d44d33c4792f0e8f826c
ARG ELIXIR_SHA256HASH=10750b8bd74b10ac1e25afab6df03e3d86999890fa359b5f02aa81de18a78e36

# --------------------------------------------------
# Environment Setup
# --------------------------------------------------

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean -y && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    locales

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8  
ENV LANGUAGE=en_US:en  
ENV LC_ALL=en_US.UTF-8

# --------------------------------------------------
# Download and extract source code
# --------------------------------------------------

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    build-essential \
    libncurses-dev \
    libssl-dev \
    libwxgtk3.2-dev

RUN wget https://github.com/erlang/otp/archive/refs/tags/OTP-29.0.tar.gz && \
    sha256sum OTP-29.0.tar.gz | grep $OTP_SHA256HASH

RUN wget https://github.com/elixir-lang/elixir/archive/refs/tags/v1.19.5.tar.gz && \
    sha256sum v1.19.5.tar.gz | grep $ELIXIR_SHA256HASH

RUN tar -xf OTP-29.0.tar.gz
RUN tar -xf v1.19.5.tar.gz

RUN rm OTP-29.0.tar.gz \
       v1.19.5.tar.gz

# --------------------------------------------------
# Erlang/OTP v29.0 Build
# --------------------------------------------------

RUN cd otp-OTP-29.0 && \
    ./otp_build configure && \
    make -j && \
    make install

# --------------------------------------------------
# Elixir v1.19.5 Build
# --------------------------------------------------

RUN cd elixir-1.19.5 && \
    make -j clean compile && \
    make -j install

# --------------------------------------------------
# Cleanup
# --------------------------------------------------

RUN rm -rf /otp-OTP-29.0 /elixir-1.19.5

RUN apt-get remove -y \
    libncurses-dev \
    build-essential \
    wget && \
    apt-get clean -y && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

# configure shell for erlexec
ENV SHELL "/usr/bin/bash"

# --------------------------------------------------
# Build Matrix Portal
# --------------------------------------------------

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    git

COPY ./matrix_portal /matrix_portal_build
RUN cd matrix_portal_build && \
    export MIX_ENV=prod && \
    mix local.hex --force && \
    mix deps.get && \
    mix compile && \
    mix assets.deploy && \
    mix phx.gen.release && \
    mix release

# --------------------------------------------------
# Release container
# --------------------------------------------------

FROM debian:trixie-slim
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates && \
    apt-get clean -y && \
    apt-get autoremove -y && \
    apt-get autoclean -y && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8  
ENV LANGUAGE=en_US:en  
ENV LC_ALL=en_US.UTF-8

COPY --from=build /matrix_portal_build/_build/prod/rel/matrix_portal /matrix_portal

RUN useradd -ms /bin/bash service
RUN chown -R service:service /matrix_portal
USER service

CMD ["/matrix_portal/bin/matrix_portal", "start"]


