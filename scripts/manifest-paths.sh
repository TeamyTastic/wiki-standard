#!/usr/bin/env bash
# Read a named string array from a wiki-standard manifest.
#
# The manifest remains ordinary JSON. This small reader deliberately supports
# only the line-oriented string arrays used for relative path declarations, so
# adoption does not require jq, Python, or a particular agent runtime.

wiki_standard_manifest_array() {
  local manifest="$1"
  local key="$2"

  if [ ! -f "$manifest" ]; then
    echo "Error: manifest '$manifest' does not exist." >&2
    return 1
  fi

  awk -v wanted="$key" '
    BEGIN { in_array = 0; found = 0; invalid = 0 }
    $0 ~ "^[[:space:]]*\"" wanted "\"[[:space:]]*:[[:space:]]*\\[" {
      found = 1
      if ($0 ~ /\[[[:space:]]*\][,]?[[:space:]]*$/) exit
      in_array = 1
      next
    }
    in_array && /^[[:space:]]*\]/ { in_array = 0; exit }
    in_array {
      line = $0
      if (line !~ /^[[:space:]]*"[^"\\]+",?[[:space:]]*$/) {
        invalid = 1
        next
      }
      sub(/^[[:space:]]*"/, "", line)
      sub(/",?[[:space:]]*$/, "", line)
      print line
    }
    END {
      if (!found) exit 3
      if (invalid || in_array) exit 2
    }
  ' "$manifest"
}

wiki_standard_manifest_scalar() {
  local manifest="$1"
  local key="$2"

  if [ ! -f "$manifest" ]; then
    echo "Error: manifest '$manifest' does not exist." >&2
    return 1
  fi

  awk -v wanted="$key" '
    BEGIN { count = 0; invalid = 0 }
    $0 ~ "^[[:space:]]*\"" wanted "\"[[:space:]]*:" {
      line = $0
      if (line !~ /^[[:space:]]*"[^"\\]+"[[:space:]]*:[[:space:]]*"[^"\\]+",?[[:space:]]*$/) {
        invalid = 1
        next
      }
      sub(/^[^:]+:[[:space:]]*"/, "", line)
      sub(/",?[[:space:]]*$/, "", line)
      print line
      count++
    }
    END {
      if (count == 0) exit 3
      if (count != 1 || invalid) exit 2
    }
  ' "$manifest"
}

wiki_standard_manifest_integer() {
  local manifest="$1"
  local key="$2"

  if [ ! -f "$manifest" ]; then
    echo "Error: manifest '$manifest' does not exist." >&2
    return 1
  fi

  awk -v wanted="$key" '
    BEGIN { count = 0; invalid = 0 }
    $0 ~ "^[[:space:]]*\"" wanted "\"[[:space:]]*:" {
      line = $0
      if (line !~ /^[[:space:]]*"[^"\\]+"[[:space:]]*:[[:space:]]*[0-9]+,?[[:space:]]*$/) {
        invalid = 1
        next
      }
      sub(/^[^:]+:[[:space:]]*/, "", line)
      sub(/,?[[:space:]]*$/, "", line)
      print line
      count++
    }
    END {
      if (count == 0) exit 3
      if (count != 1 || invalid) exit 2
    }
  ' "$manifest"
}

wiki_standard_validate_relative_path() {
  local path="$1"
  case "$path" in
    ''|/*|.|..|../*|*/../*|*/..|*\\*|*\**|*\?*|*\[*|*\]*) return 1 ;;
    *) return 0 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ "$#" -eq 2 ]; then
    wiki_standard_manifest_array "$1" "$2"
  elif [ "$#" -eq 3 ] && [ "$1" = "--scalar" ]; then
    wiki_standard_manifest_scalar "$2" "$3"
  elif [ "$#" -eq 3 ] && [ "$1" = "--integer" ]; then
    wiki_standard_manifest_integer "$2" "$3"
  else
    echo "Usage: $(basename "$0") [--scalar|--integer] <manifest.json> <key>" >&2
    exit 1
  fi
fi
