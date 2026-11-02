FROM public.ecr.aws/amazonlinux/amazonlinux:2023

# AgentCore Harness は ARM64 を使用
RUN test "$(uname -m)" = "aarch64"

# ハーネスの基本操作・AWS CLI導入に必要なパッケージ
RUN dnf install -y \
    bash \
    coreutils-single \
    tar \
    gzip \
    unzip \
    curl-minimal \
    ca-certificates \
    less \
    groff-base \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# AWS CLI v2
ARG AWS_CLI_VERSION=2.39.3

RUN curl -fsSL \
    "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_CLI_VERSION}.zip" \
    -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && aws --version \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

ENV AWS_DEFAULT_REGION=ap-northeast-1 \
    AWS_PAGER="" \
    AWS_CLI_AUTO_PROMPT=off

WORKDIR /workspace
