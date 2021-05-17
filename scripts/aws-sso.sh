#!/bin/bash

aws sso login --profile $AWS_SSO_PROFILE
touch /root/.aws/credentials
mkdir -p /root/.aws/sso/cache
echo | dnxsso -e -p $AWS_SSO_PROFILE