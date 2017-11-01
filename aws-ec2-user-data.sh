#!/usr/bin/env bash
#===============================================================================
#   DESCRIPTION: aws-ec2-user-data.sh
#        AUTHOR: Aleksandr Kukhar (kyxap), kyxap@kyxap.pro
#       CREATED: 11/01/17 23:13 +0000 UTC
#===============================================================================
set -o pipefail
set -eu

usage_='^(help|usage)$'
usage() {
  echo "To restart cloud-init:" >&2
  echo "  rm -rf /var/lib/cloud/{instance,instances/*,sem/*}" >&2
  echo "  cloud-init init && cloud-init modules --mode config && cloud-init modules --mode final" >&2
  echo >&2
  echo "Usage:">&2
  echo "  INSTANCES=\"i-12345678 i-87654321\" ${0} <read|update|usage>" >&2  
  exit 2
}

trap "usage" INT TERM

INSTANCES=(${INSTANCES[@]:?})
SCRIPT=userdata.txt

fmt_read="aws ec2 describe-instance-attribute --instance-id ${INSTANCES[0]} --attribute userData --query 'UserData.Value' --output text | base64 -d > ${SCRIPT}"
fmt_stop="aws ec2 stop-instances --instance-ids ${INSTANCES[@]}; aws ec2 wait instance-stopped --instance-ids ${INSTANCES[@]}"
fmt_encode="base64 ${SCRIPT} > ${SCRIPT%.*}.base64"
fmt_update="aws ec2 modify-instance-attribute --instance-id %s --attribute userData --value file:///${SCRIPT%.*}.base64"
fmt_start="aws ec2 start-instances --instance-ids ${INSTANCES[@]}; aws ec2 wait instance-running --instance-ids ${INSTANCES[@]}"

data() {
  local action=${1:?}
  shift
  local -a arr=(${@:-${INSTANCES[@]}})
  local format="fmt_${action}"
  printf "${!format}\n" "${arr[@]}"
}

finish() { exit 0; }

CMD=${@:-usage}

[[ ${CMD} == read ]] && { data read && finish; }
[[ ${CMD} == update ]] && { data encode && data stop; data update; data start && finish; }
[[ ${CMD} =~ ${usage_} ]] && { usage && finish; }

usage
exit 0
