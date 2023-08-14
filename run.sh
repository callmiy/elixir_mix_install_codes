#!/bin/bash
# shellcheck disable=2009

function d {
  local _filename="${1}"

  if [ -z "${_filename}" ]; then
    echo "file name required"
    exit
  fi

  clear

  local _kill_cmd="bash -c ' ./run.sh kill-d ${_filename} ' "
  local _cmd="elixir ${_filename}"

  chokidar \
    "${_filename}" \
    --initial \
    -c "${_kill_cmd} ; ${_cmd}"
}

function kill-d {
  lsof -i :5001 |
    awk '{print $2}' |
    xargs kill -KILL &>/dev/null
}

function play-pids {
  ps aux |
    grep "${PWD}"/assets/node_modules/.bin/playwright |
    g -v grep |
    awk '{print $2}'
}

function kill-play {
  ps aux |
    grep "${PWD}"/assets/node_modules/.bin/playwright |
    g -v grep |
    awk '{print $2}' |
    xargs kill -9
}

function play-t {
  mkdir -p "${PWD}"/assets/gen/tmp

  (
    cd ./assets || exit 1

    yarn playwright test --config ./playwright/config.js "${@}"
  )
}

function play-t-w {
  local _cmd="bash -c './run.sh play-t'"
  local _kill_cmd="bash -c './run.sh kill-play'"

  chokidar assets/playwright/** \
    --initial \
    -c "${_cmd}"
}

function help {
  : "List available tasks."

  mapfile -t names < <(compgen -A function | grep -v '^_')

  local len=0
  declare -A names_map=()

  for name in "${names[@]}"; do
    _len="${#name}"
    names_map["$name"]="${_len}"
    if [[ "${_len}" -gt "${len}" ]]; then len=${_len}; fi
  done

  len=$((len + 10))

  for name in "${names[@]}"; do
    local spaces=""
    _len="${names_map[$name]}"
    _len=$((len - _len))

    for _ in $(seq "${_len}"); do
      spaces="${spaces}-"
      ((++t))
    done

    mapfile -t doc1 < <(
      type "$name" |
        sed -nEe "s/^[[:space:]]*: ?\"(.*)\";/\1/p"

    )

    if [[ -n "${doc1[*]}" ]]; then
      for _doc in "${doc1[@]}"; do
        echo -e "${name} ${spaces} ${_doc}"
      done
    else
      echo "${name} ${spaces} *************"
    fi

    echo
  done
}

TIMEFORMAT=$'\n\nTask completed in %3lR\n'
time "${@:-help}"
