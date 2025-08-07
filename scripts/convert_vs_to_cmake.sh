#!/usr/bin/env bash
# Convert a Visual Studio solution (.sln) into a basic CMake project.
# Usage: ./convert_vs_to_cmake.sh path/to/solution.sln

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <solution.sln>" >&2
    exit 1
fi

sln="$1"
root_dir=$(dirname "$sln")
sol_name=$(basename "${sln%.sln}")
root_cmake="$root_dir/CMakeLists.txt"

{
  echo "cmake_minimum_required(VERSION 3.10)"
  echo "project($sol_name)"
  echo
} > "$root_cmake"

while IFS= read -r line; do
    proj_name=$(echo "$line" | cut -d '"' -f4)
    proj_path=$(echo "$line" | cut -d '"' -f6)
    proj_file="$root_dir/$proj_path"
    [[ -f "$proj_file" ]] || continue

    proj_dir=$(dirname "$proj_path")
    config_type=$(grep -oP '(?<=<ConfigurationType>)[^<]+' "$proj_file" | head -n1)

    mapfile -t sources < <(grep -oP '(?<=<ClCompile Include=")[^"]+' "$proj_file" | tr '\\' '/')

    if [[ "$config_type" == "StaticLibrary" ]]; then
        lib_cmake="$root_dir/$proj_dir/CMakeLists.txt"
        {
          echo "add_library(${proj_name} STATIC"
          for src in "${sources[@]}"; do
              echo "    ${src}"
          done
          echo ")"
        } > "$lib_cmake"

        [[ "$proj_dir" != "." ]] && echo "add_subdirectory($proj_dir)" >> "$root_cmake"
    else
        if [[ "$proj_dir" != "." ]]; then
            for i in "${!sources[@]}"; do
                sources[$i]="$proj_dir/${sources[$i]}"
            done
        fi
        {
          echo "add_executable(${proj_name}"
          for src in "${sources[@]}"; do
              echo "    ${src}"
          done
          echo ")"
        } >> "$root_cmake"
    fi
done < <(grep '^Project(' "$sln")
