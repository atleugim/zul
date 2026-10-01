#!/bin/zsh
# Builds MediaRemoteAdapter.framework into Vendor/build, where the Xcode
# "Embed MediaRemote Adapter" phase copies it from.
set -euo pipefail

root=${0:A:h:h}
source_dir=$root/Vendor/mediaremote-adapter
build_dir=$root/Vendor/build

cmake -S "$source_dir" -B "$build_dir" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir" --target MediaRemoteAdapter
