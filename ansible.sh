#!/usr/bin/env bash

###
#
# Wrapper for calling Ansible
#
###

# prerequisites

software=(ansible jq vault curl)

for item in "${software[@]}"; do
  if [[ ! -x $(which ${item}) ]]; then
    echo "${item} missing!"
    exit 1
  fi
done

# functions
ssh_sign() {

  vault write -field=signed_key ssh/sign/sean public_key=@$HOME/.ssh/id_rsa.pub >$HOME/.ssh/id_rsa-cert.pub

}

# environment variables
if [[ $(systemctl is-active vault) == "active" ]]; then
  if [[ $(curl -s https://bombadil.ttys0.net:8200/v1/sys/seal-status | jq .sealed) == "false" ]]; then
    export VAULT_ADDR='https://bombadil.ttys0.net:8200'
  else
    echo "Vault is sealed!"
    exit 1
  fi
else
  echo "Vault is not running!"
  exit 1
fi

if [ -d $(pwd)/ansible/plugins ]; then
  export ANSIBLE_LIBARY="$(pwd)/ansible/plugins"
else
  echo "Ansible plugins dir missing!"
  exit 1
fi

# call Vault to sign SSH key

touch $HOME/.vault-token

vtoken=$(cat $HOME/.vault-token)
token_check=$(curl -s --header "X-Vault-Token:${vtoken}" ${VAULT_ADDR}/v1/auth/token/lookup-self | jq -r ".errors[]?")

if [[ "$token_check" == "permission denied" || "$token_check" == "missing client token" ]]; then
  echo "Regenerating Vault Token...."
  vault login -method=userpass username=$USER
  export VAULT_TOKEN=$(cat $HOME/.vault-token)
  ssh_sign
else
  export VAULT_TOKEN=$(cat $HOME/.vault-token)
  ssh_sign
fi

# call Ansible

cd ansible
$(which ansible) "$@"
