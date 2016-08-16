#!/usr/bin/env bash
function gnome_up () {
gnome-terminal   \
  --tab -e 'env' -t 'debug' \
  --tab -e 'gnome-run edith rake dev:run' -t 'edith' \
  --tab -e 'gnome-run rogers rails s' -t 'rogers r'   \
  --tab -e 'gnome-run jarvis rails s' -t 'jarvis r'   \
  --tab -e 'gnome-run jarvis rake jobs:work' -t 'jarvis dj'   \
  --tab -e 'gnome-run frick rails s' -t 'frick r'   \
  --tab -e 'gnome-run frick rake kinesis_subscriber:ingestion:start' -t 'frick k'   \
  --tab -e 'gnome-run warehouse rake kinesis_subscriber:ingestion:start' -t 'warehouse k'   \
  --tab -e 'gnome-run stone rails s' -t 'stone s'       \
  --tab -e 'gnome-run stone rake jobs:work' -t 'stone dj'
  --tab -e 'gnome-run edith rake dev:run' -t 'edith'
}
