#!/bin/sh

function s3_touch() {
  case $1 in
  s3://* ) ;;
  * ) echo "usage: s3_touch s3://full_path" 1>&2 ; 
      return
      ;;
  esac
  now=$(date --iso-8601=seconds)
  aws s3 cp --metadata '{"touched":"${GR_USERNAME} ${now}"}' $1 $1
}
