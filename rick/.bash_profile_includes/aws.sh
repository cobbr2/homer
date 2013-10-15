export JAVA_HOME=/usr
export EC2_HOME=${HOME}/ec2
export PATH=${PATH}:${EC2_HOME}/bin
export EC2_CERT=${HOME}/.ec2/cert.pem
export EC2_PRIVATE_KEY=${HOME}/.ec2/pk.pem
#export EC2_URL=https://ec2.us-west-2.amazonaws.com
export EC2_URL=https://ec2.us-east-1.amazonaws.com

export AWS_IAM_HOME=$HOME/IAMCli-1.5.0
export PATH=${PATH}:${AWS_IAM_HOME}/bin
export AWS_CREDENTIAL_FILE=$HOME/.aws_keys
