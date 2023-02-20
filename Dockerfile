FROM tbrock/saw:v0.2.2 as saw


FROM python:alpine3.17

ENV AWSCLI_VERSION=2.2.0

RUN apk --no-cache update && \
    apk --no-cache add \
        binutils \
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
        git  && \
    pip3 --no-cache-dir install --upgrade pip setuptools dnxsso boto3 && \
    update-ca-certificates && \
    pip install awscliv2==$AWSCLI_VERSION  && \
    ln -s /usr/local/bin/awscliv2 /usr/local/bin/aws && \
    rm -rf /var/cache/apk/*

COPY --from=saw /bin/saw /bin/saw

COPY scripts /opt/scripts

ENV PATH "$PATH:/opt/scripts"

WORKDIR /work

ENTRYPOINT [ "aws" ]

CMD [ "--version" ]