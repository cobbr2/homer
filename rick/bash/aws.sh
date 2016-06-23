#!/usr/bin/env sh
# Can probably remove all of these:
export JAVA_HOME=/usr
export EC2_HOME=${HOME}/ec2
export PATH=${PATH}:${EC2_HOME}/bin
export EC2_CERT=${HOME}/.ec2/cert.pem
export EC2_PRIVATE_KEY=${HOME}/.ec2/pk.pem
export EC2_URL=https://ec2.us-east-1.amazonaws.com

gpg_agent_working && aws-environment development
