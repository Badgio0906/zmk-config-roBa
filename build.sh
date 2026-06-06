#!/bin/bash

rm -rf ./config/* && cp -r ./zmk-config/config/* ./config/
while IFS=$'\t' read board shield snippet artifact args; do

  if [[ -z $board || -z $shield ]]; then continue; fi
  name=${artifact:-${shield:+$shield-}${board//\//_}-zmk}

  args="$args -DSHIELD="$shield""
  args="$args -DZMK_CONFIG="$(pwd)/config""
  if [ -e ./zmk-config/zephyr/module.yml ]; then

    args="$args -DZMK_EXTRA_MODULES="$(pwd)/zmk-config""
  fi

  (
    echo start build $name
    rm -rf "./build/$name" "./output/$name".*
    build_dir="${name// /_}"
    west build -p always -d "./.build/$build_dir" -s zmk/app \
      -b "$board" ${snippet:+-S "$snippet"} -- $args &> "./output/$name.log"

    echo end build[$?] $name

    zephyr="./.build/$build_dir/zephyr"
    cat -s "$zephyr/zephyr.dts" &> "./output/$name.dts"
    cat -s "$zephyr/zephyr.dts.pre" &> "./output/$name.dts.pre"
    grep -v -e "^#" -e "^$" "$zephyr/.config" | sort &> "./output/$name.config"
    for zmk in "$zephyr"/zmk.*; do cp "$zmk" "./output/${name}${zmk##*/zmk}"; done
  ) &
done < <(yq -r '.include[] | [.board, .shield, .snippet, ."artifact-name", ."cmake-args"] | @tsv' ./zmk-config/build.yaml); wait
