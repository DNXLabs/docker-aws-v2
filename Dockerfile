ARG ALPINE_VERSION=3.17

FROM tbrock/saw:v0.2.2 as saw

FROM python:3.11-alpine${ALPINE_VERSION} as base

FROM base as builder
ARG AWS_CLI_VERSION=2.15.8

WORKDIR /aws-cli

RUN apk add --no-cache  groff build-base libffi-dev cmake curl \
    && mkdir /opt/download \
    && curl -s -L https://github.com/aws/aws-cli/archive/refs/tags/${AWS_CLI_VERSION}.tar.gz -o /opt/download/aws_cli.tar.gz \
    && tar -vzxf /opt/download/aws_cli.tar.gz -C /aws-cli  --strip-components=1 \
    && pip install --no-cache-dir --upgrade pip  \
    && python -m venv venv \
    && . venv/bin/activate \
    && scripts/installers/make-exe \
    && unzip -q dist/awscli-exe.zip \
    && aws/install --bin-dir /aws-cli-bin \
    && /aws-cli-bin/aws --version

FROM golang:1.15.3-alpine as ssm-builder

ARG VERSION=1.2.279.0

RUN set -ex && apk add --no-cache make git gcc libc-dev curl bash zip && \
    curl -sLO https://github.com/aws/session-manager-plugin/archive/${VERSION}.tar.gz && \
    mkdir -p /go/src/github.com && \
    tar xzf ${VERSION}.tar.gz && \
    mv session-manager-plugin-${VERSION} /go/src/github.com/session-manager-plugin && \
    cd /go/src/github.com/session-manager-plugin && \
    make release

# build the final image
FROM base as final
RUN apk add --no-cache  binutils \
        libffi-dev \
        openssl-dev \
        ca-certificates \
        groff \
        less \
        bash \
        make \
        jq \
        gettext-dev \
        wget \
        curl \
        g++ \
        zip \
        git \
        expect \
    && pip install --no-cache-dir --upgrade pip && pip --no-cache-dir install setuptools dnxsso \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*


COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
COPY --from=saw /bin/saw /bin/saw
COPY --from=ssm-builder /go/src/github.com/session-manager-plugin/bin/linux_amd64_plugin/session-manager-plugin /usr/local/bin/

COPY scripts /opt/scripts

ENV PATH "$PATH:/opt/scripts"

WORKDIR /work

ENTRYPOINT [ "aws" ]

CMD [ "--version" ]