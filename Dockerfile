ARG ALPINE_VERSION=3.17

FROM tbrock/saw:v0.2.2 as saw

FROM python:3.11-alpine${ALPINE_VERSION} as base

FROM base as builder
ARG AWS_CLI_VERSION=2.14.6

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
    && pip install --no-cache-dir --upgrade pip && pip --no-cache-dir install setuptools dnxsso \
    && update-ca-certificates \
    && rm -rf /var/cache/apk/*


COPY --from=builder /usr/local/aws-cli/ /usr/local/aws-cli/
COPY --from=builder /aws-cli-bin/ /usr/local/bin/
COPY --from=saw /bin/saw /bin/saw

COPY scripts /opt/scripts

ENV PATH "$PATH:/opt/scripts"

WORKDIR /work

ENTRYPOINT [ "aws" ]

CMD [ "--version" ]