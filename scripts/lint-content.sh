#!/usr/bin/env bash
# lint-content.sh <target-wiki-dir> [--stale-months N]
#
# Content-health lint for a wiki-standard wiki. Unlike check-standard.sh
# (which verifies the STANDARD's own files are present/unmodified), this
# script inspects the wiki's actual CONTENT and reports:
#
#   - Orphan notes    — nothing anywhere in the wiki links to them
#   - Broken links    — a [[wikilink]] target that resolves to no note
#   - Stale notes     — `updated` (or `created`) older than --stale-months
#                       (default 18, per the llm-wiki-compiler convention)
#   - Open conflicts  — notes with an unresolved `## Conflicts` heading
#   - Missing links   — note pairs sharing 2+ tags with no link either way
#                       (a proxy for "shared source, no mutual link"; this
#                       standard's `source` field is a single scalar, not a
#                       list, so tag-overlap is used instead of citation
#                       overlap — see conventions/metadata.md)
#
# This is a REPORT-ONLY tool intended for the Consolidate lifecycle stage.
# It does not edit, move, merge, or delete anything.
#
# NOT covered: genuine semantic contradiction detection between notes. That
# requires reading and understanding content, which is an agent's job, not
# a shell script's. This tool only surfaces notes that already carry an
# explicit `## Conflicts` heading (per conventions/editing-rules.md) so an
# agent can act on them during Consolidate — it cannot discover an
# unflagged contradiction on its own.
#
# Directories excluded from linting (shared-asset or non-content):
#   conventions/ templates/ scripts/ _archive/ _staging/ .git/ .obsidian/
# Root files excluded: CLAUDE.md, README.md, log.md, .wiki-standard-version
#
# _archive/ and _staging/ files are excluded from the lint TARGET set (an
# archived note isn't expected to have live inbound links; a staged note
# hasn't reached Connect yet) but their links still count toward resolving
# other notes' orphan/broken-link status.
#
# Exit code: 0 if nothing to report; non-zero if any orphans, broken links,
# stale notes, open conflicts, or missing-link suggestions were found.
#
# macOS/BSD-safe: no GNU-only flags, no bash associative arrays (macOS ships
# bash 3.2), pairwise/set logic is delegated to awk instead.

set -euo pipefail

STALE_MONTHS=18
TARGET_DIR_ARG=""

usage() {
  echo "Usage: $(basename "$0") <target-wiki-dir> [--stale-months N]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --stale-months)
      if [ "$#" -lt 2 ]; then
        echo "Error: --stale-months requires a value" >&2
        exit 2
      fi
      case "$2" in
        *[!0-9]*) echo "Error: --stale-months requires a positive integer" >&2; exit 2 ;;
      esac
      STALE_MONTHS="$2"
      shift 2
      ;;
    --*)
      echo "Error: unknown option '$1'" >&2
      usage
      exit 2
      ;;
    *)
      if [ -n "$TARGET_DIR_ARG" ]; then
        echo "Error: unexpected extra argument '$1'" >&2
        usage
        exit 2
      fi
      TARGET_DIR_ARG="$1"
      shift
      ;;
  esac
done

if [ -z "$TARGET_DIR_ARG" ]; then
  usage
  exit 2
fi

if [ ! -d "$TARGET_DIR_ARG" ]; then
  echo "Error: target directory '$TARGET_DIR_ARG' does not exist." >&2
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR_ARG" && pwd)"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

MANIFEST="${WORKDIR}/manifest.tsv"        # relpath \t basename \t title \t updated \t status
CANDIDATES="${WORKDIR}/candidates.tsv"    # relpath \t candidate_name
LINKS="${WORKDIR}/links.tsv"              # source_relpath \t target_name
TAGROWS="${WORKDIR}/tagrows.tsv"          # relpath \t tag
: > "$MANIFEST"
: > "$CANDIDATES"
: > "$LINKS"
: > "$TAGROWS"

is_excluded_rel() {
  case "$1" in
    conventions/*|templates/*|scripts/*|_archive/*|_staging/*|.git/*|.obsidian/*|node_modules/*|.wiki-standard-backup-*/*) return 0 ;;
    CLAUDE.md|README.md|log.md) return 0 ;;
    *) return 1 ;;
  esac
}

is_content_rel() {
  # content = search-universe minus archive/staging (see header comment)
  case "$1" in
    _archive/*|_staging/*) return 1 ;;
    *) return 0 ;;
  esac
}

extract_scalar_field() {
  # $1 = file, $2 = frontmatter field name
  local file="$1" field="$2"
  awk -v f="$field" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---" { exit }
    infm && $0 ~ "^"f":" {
      sub("^"f":[ \t]*", "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$file"
}

extract_list_field() {
  # $1 = file, $2 = frontmatter field name -> prints comma-separated raw list body
  local file="$1" field="$2"
  awk -v f="$field" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---" { exit }
    infm && $0 ~ "^"f":" {
      sub("^"f":[ \t]*", "")
      gsub(/^\[|\]$/, "")
      print
      exit
    }
  ' "$file"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

epoch_for_date() {
  # $1 = YYYY-MM-DD -> prints epoch seconds, or nothing if unparseable
  local d="$1"
  date -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null && return 0
  date -d "$d" +%s 2>/dev/null && return 0
  return 1
}

echo "wiki-content-lint"
echo "  target:       $TARGET_DIR"
echo "  stale-months:  $STALE_MONTHS"
echo ""

# --- Pass 1: build manifest, candidate names, tag rows, and link rows ---

ALL_MD_FILES="${WORKDIR}/all_md_files.txt"
find "$TARGET_DIR" -type f -name '*.md' | while IFS= read -r f; do
  rel="${f#"$TARGET_DIR"/}"
  is_excluded_rel "$rel" && continue
  printf '%s\n' "$rel"
done > "$ALL_MD_FILES"

while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  file="${TARGET_DIR}/${rel}"
  base="$(basename "$rel" .md)"
  title="$(extract_scalar_field "$file" title)"
  updated="$(extract_scalar_field "$file" updated)"
  created="$(extract_scalar_field "$file" created)"
  status="$(extract_scalar_field "$file" status)"
  effective_date="${updated:-$created}"

  if is_content_rel "$rel"; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$rel" "$base" "$title" "$effective_date" "$status" >> "$MANIFEST"
  fi

  # Candidate names this note can be linked BY (basename, title, aliases)
  printf '%s\t%s\n' "$rel" "$base" >> "$CANDIDATES"
  if [ -n "$title" ]; then
    printf '%s\t%s\n' "$rel" "$title" >> "$CANDIDATES"
  fi
  aliases_raw="$(extract_list_field "$file" aliases)"
  if [ -n "$aliases_raw" ]; then
    IFS=',' read -ra alias_arr <<< "$aliases_raw"
    for a in "${alias_arr[@]}"; do
      a_trimmed="$(trim "$a")"
      a_trimmed="${a_trimmed%\"}"; a_trimmed="${a_trimmed#\"}"
      [ -n "$a_trimmed" ] && printf '%s\t%s\n' "$rel" "$a_trimmed" >> "$CANDIDATES"
    done
  fi

  # Tags (content notes only — no point suggesting links involving archive/staging)
  if is_content_rel "$rel"; then
    tags_raw="$(extract_list_field "$file" tags)"
    if [ -n "$tags_raw" ]; then
      IFS=',' read -ra tag_arr <<< "$tags_raw"
      for t in "${tag_arr[@]}"; do
        t_trimmed="$(trim "$t")"
        [ -n "$t_trimmed" ] && printf '%s\t%s\n' "$rel" "$t_trimmed" >> "$TAGROWS"
      done
    fi
  fi

  # Wikilinks found in this file's body: [[Target]] or [[Target|Alias]]
  # grep exits 1 (no match) for any note with zero wikilinks — a normal,
  # expected case, not a real failure — so it's explicitly caught here
  # rather than letting `pipefail` + `set -e` kill the whole script on the
  # first link-free note encountered.
  wikilinks_raw="$(grep -oE '\[\[[^]]+\]\]' "$file" 2>/dev/null | sed -E 's/^\[\[//; s/\]\]$//; s/\|.*$//' || true)"
  if [ -n "$wikilinks_raw" ]; then
    while IFS= read -r tgt; do
      tgt_trimmed="$(trim "$tgt")"
      [ -n "$tgt_trimmed" ] && printf '%s\t%s\n' "$rel" "$tgt_trimmed" >> "$LINKS"
    done <<< "$wikilinks_raw"
  fi
done < "$ALL_MD_FILES"

# External roots (optional): $TARGET_DIR/.lint-external-roots lists directories
# OUTSIDE this bundle whose notes are valid wikilink targets — e.g. when the
# bundle is mounted inside a larger vault and links resolve vault-wide.
# One path per line, ~ allowed, blank lines and #-comments ignored.
# External notes contribute link-target CANDIDATES only: they are never
# scanned as content, so they can't appear as orphans/stale/broken themselves.
EXT_ROOTS_FILE="$TARGET_DIR/.lint-external-roots"
if [ -f "$EXT_ROOTS_FILE" ]; then
  while IFS= read -r ext_root; do
    ext_root="$(trim "$ext_root")"
    case "$ext_root" in ''|'#'*) continue ;; esac
    ext_root="${ext_root/#\~/$HOME}"
    if [ ! -d "$ext_root" ]; then
      echo "  (external root not found, skipped: $ext_root)" >&2
      continue
    fi
    find "$ext_root" -type f -name '*.md' | while IFS= read -r ef; do
      ebase="$(basename "$ef" .md)"
      printf 'EXTERNAL:%s\t%s\n' "$ef" "$ebase" >> "$CANDIDATES"
      etitle="$(extract_scalar_field "$ef" title)"
      [ -n "$etitle" ] && printf 'EXTERNAL:%s\t%s\n' "$ef" "$etitle" >> "$CANDIDATES"
      ealiases="$(extract_list_field "$ef" aliases)"
      if [ -n "$ealiases" ]; then
        IFS=',' read -ra ealias_arr <<< "$ealiases"
        for ea in "${ealias_arr[@]}"; do
          ea_trimmed="$(trim "$ea")"
          ea_trimmed="${ea_trimmed%\"}"; ea_trimmed="${ea_trimmed#\"}"
          [ -n "$ea_trimmed" ] && printf 'EXTERNAL:%s\t%s\n' "$ef" "$ea_trimmed" >> "$CANDIDATES"
        done
      fi
    done
  done < "$EXT_ROOTS_FILE"
fi

TOTAL_CONTENT="$(wc -l < "$MANIFEST" | tr -d ' ')"

# --- Resolve links: which relpaths does each link target correspond to? ---

RESOLVED_LINKS="${WORKDIR}/resolved_links.tsv"   # source_relpath \t target_relpath
BROKEN_LINKS="${WORKDIR}/broken_links.tsv"       # source_relpath \t target_name (unresolved)
LINKED_RELPATHS="${WORKDIR}/linked_relpaths.txt" # relpaths that have >=1 inbound resolved link

awk -F'\t' '
  FNR==NR { cand[tolower($2)] = cand[tolower($2)] "\x1f" $1; next }
  {
    tgt = tolower($2)
    if (tgt in cand) {
      n = split(cand[tgt], owners, "\x1f")
      matched = 0; self_only = 1
      for (i=1; i<=n; i++) {
        if (owners[i] != "" && owners[i] != $1) {
          print $1"\t"owners[i] >> "'"$RESOLVED_LINKS"'"
          print owners[i] >> "'"$LINKED_RELPATHS"'"
          matched = 1; self_only = 0
        } else if (owners[i] == $1) {
          self_only = 1
        }
      }
      if (!matched && !self_only) print $1"\t"$2 >> "'"$BROKEN_LINKS"'"
    } else {
      print $1"\t"$2 >> "'"$BROKEN_LINKS"'"
    }
  }
' "$CANDIDATES" "$LINKS"

touch "$RESOLVED_LINKS" "$BROKEN_LINKS" "$LINKED_RELPATHS"
sort -u "$LINKED_RELPATHS" -o "$LINKED_RELPATHS"

# --- Report: Orphans ---

echo "## Orphan notes (no inbound links found anywhere in the wiki)"
ORPHAN_COUNT=0
while IFS=$'\t' read -r rel base title updated status; do
  [ -z "$rel" ] && continue
  if ! grep -qxF "$rel" "$LINKED_RELPATHS" 2>/dev/null; then
    printf '  [ORPHAN]    %s\n' "$rel"
    ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
  fi
done < "$MANIFEST"
[ "$ORPHAN_COUNT" -eq 0 ] && echo "  none"
echo ""

# --- Report: Broken links (from content notes only) ---

echo "## Broken links (wikilink target resolves to no note in the wiki)"
BROKEN_COUNT=0
if [ -s "$BROKEN_LINKS" ]; then
  while IFS=$'\t' read -r src tgt; do
    is_content_rel "$src" || continue
    printf '  [RED LINK]  %s -> [[%s]]\n' "$src" "$tgt"
    BROKEN_COUNT=$((BROKEN_COUNT + 1))
  done < "$BROKEN_LINKS"
fi
[ "$BROKEN_COUNT" -eq 0 ] && echo "  none"
echo "  (a red link isn't necessarily wrong — conventions/linking.md allows"
echo "   linking to a note that doesn't exist yet as a stub. Review, don't"
echo "   auto-fix.)"
echo ""

# --- Report: Stale notes ---

echo "## Stale notes (updated/created more than ${STALE_MONTHS} months ago)"
STALE_COUNT=0
NOW_EPOCH="$(date +%s)"
while IFS=$'\t' read -r rel base title effdate status; do
  [ -z "$rel" ] && continue
  [ -z "$effdate" ] && continue
  note_epoch="$(epoch_for_date "$effdate" || true)"
  [ -z "$note_epoch" ] && continue
  age_days=$(( (NOW_EPOCH - note_epoch) / 86400 ))
  age_months=$(( age_days / 30 ))
  if [ "$age_months" -ge "$STALE_MONTHS" ]; then
    printf '  [STALE]     %s (last touched %s, ~%s months ago)\n' "$rel" "$effdate" "$age_months"
    STALE_COUNT=$((STALE_COUNT + 1))
  fi
done < "$MANIFEST"
[ "$STALE_COUNT" -eq 0 ] && echo "  none"
echo ""

# --- Report: Open conflicts ---

echo "## Open conflicts (notes with an unresolved ## Conflicts heading)"
CONFLICT_COUNT=0
while IFS=$'\t' read -r rel base title effdate status; do
  [ -z "$rel" ] && continue
  if grep -q '^## Conflicts' "${TARGET_DIR}/${rel}" 2>/dev/null; then
    printf '  [CONFLICT]  %s\n' "$rel"
    CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
  fi
done < "$MANIFEST"
[ "$CONFLICT_COUNT" -eq 0 ] && echo "  none"
echo "  (semantic contradictions this script can't see are not covered —"
echo "   this only finds notes already flagged per editing-rules.md.)"
echo ""

# --- Report: Missing-link suggestions (shared tags, no link either way) ---

echo "## Suggested connections (2+ shared tags, no link either direction)"
SHARED_PAIRS="${WORKDIR}/shared_pairs.tsv"
: > "$SHARED_PAIRS"
if [ -s "$TAGROWS" ]; then
  awk -F'\t' '
    {
      tag = $2; note = $1
      notes_for_tag[tag] = notes_for_tag[tag] "\x1f" note
    }
    END {
      for (t in notes_for_tag) {
        n = split(notes_for_tag[t], arr, "\x1f")
        for (i=1; i<=n; i++) {
          for (j=i+1; j<=n; j++) {
            a = arr[i]; b = arr[j]
            if (a == "" || b == "" || a == b) continue
            key = (a < b) ? a"\x1e"b : b"\x1e"a
            pair_count[key]++
            pair_tags[key] = pair_tags[key] (pair_tags[key] == "" ? "" : ",") t
          }
        }
      }
      for (k in pair_count) {
        if (pair_count[k] >= 2) {
          split(k, parts, "\x1e")
          print parts[1]"\t"parts[2]"\t"pair_count[k]"\t"pair_tags[k]
        }
      }
    }
  ' "$TAGROWS" > "$SHARED_PAIRS"
fi

SUGGEST_COUNT=0
if [ -s "$SHARED_PAIRS" ]; then
  while IFS=$'\t' read -r a b count tags; do
    [ -z "$a" ] && continue
    a_links_b=0
    b_links_a=0
    grep -qxF "$(printf '%s\t%s' "$a" "$b")" "$RESOLVED_LINKS" 2>/dev/null && a_links_b=1
    grep -qxF "$(printf '%s\t%s' "$b" "$a")" "$RESOLVED_LINKS" 2>/dev/null && b_links_a=1
    if [ "$a_links_b" -eq 0 ] && [ "$b_links_a" -eq 0 ]; then
      printf '  [SUGGEST]   %s <-> %s (shared tags: %s)\n' "$a" "$b" "$tags"
      SUGGEST_COUNT=$((SUGGEST_COUNT + 1))
    fi
  done < "$SHARED_PAIRS"
fi
[ "$SUGGEST_COUNT" -eq 0 ] && echo "  none"
echo "  (tag-overlap proxy, not citation overlap — this standard's 'source'"
echo "   field is a single scalar, not a list. See conventions/metadata.md.)"
echo ""

echo "Summary: ${TOTAL_CONTENT} content notes scanned."
echo "  ${ORPHAN_COUNT} orphan, ${BROKEN_COUNT} broken link(s), ${STALE_COUNT} stale,"
echo "  ${CONFLICT_COUNT} open conflict(s), ${SUGGEST_COUNT} suggested connection(s)."

TOTAL_ISSUES=$((ORPHAN_COUNT + BROKEN_COUNT + STALE_COUNT + CONFLICT_COUNT + SUGGEST_COUNT))
if [ "$TOTAL_ISSUES" -gt 0 ]; then
  exit 1
fi
exit 0
