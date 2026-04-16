#!/bin/bash
# Generates lightweight static index.html files for every directory,
# mimicking archive.archlinux.org's plain directory listing.
#
# Usage: ./generate-index.sh [github-raw-base-url]
# Example: ./generate-index.sh https://github.com/petexy/linexin-repo-archive/raw/main

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
RAW_BASE="${1:-}"

generate_index() {
    local dir="$1"
    local rel_path="${dir#"$REPO_ROOT"}"
    rel_path="${rel_path#/}"

    # Skip .git and docs directories
    [[ "$rel_path" == .git* ]] && return

    local title="/"
    [[ -n "$rel_path" ]] && title="/${rel_path}/"

    local index_file="${dir}/index.html"
    local entries=()

    # Collect subdirectories
    while IFS= read -r -d '' entry; do
        local name
        name="$(basename "$entry")"
        [[ "$name" == .git ]] && continue
        entries+=("d|${name}/")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

    # Collect files
    while IFS= read -r -d '' entry; do
        local name
        name="$(basename "$entry")"
        [[ "$name" == "index.html" ]] && continue
        [[ "$name" == "generate-index.sh" ]] && continue
        [[ "$name" == ".gitattributes" ]] && continue
        entries+=("f|${name}")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -type f -print0 | sort -z)

    # Build HTML
    {
        cat <<'HEADER'
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
HEADER
        echo "<title>Index of ${title}</title>"
        cat <<'STYLE'
<style>
body { font-family: monospace; font-size: 14px; margin: 20px; background: #fff; color: #333; }
h1 { font-size: 18px; font-weight: normal; }
a { color: #0057b7; text-decoration: none; }
a:hover { text-decoration: underline; }
pre { line-height: 1.6; }
</style>
</head>
<body>
STYLE
        echo "<h1>Index of ${title}</h1>"
        echo "<pre>"

        # Parent directory link
        if [[ -n "$rel_path" ]]; then
            echo '<a href="../">../</a>'
        fi

        # List entries
        for entry in "${entries[@]}"; do
            local type="${entry%%|*}"
            local name="${entry#*|}"

            if [[ "$type" == "d" ]]; then
                echo "<a href=\"${name}\">${name}</a>"
            else
                # For package files, link to raw GitHub URL for direct download
                if [[ -n "$RAW_BASE" && ("$name" == *.pkg.tar.zst || "$name" == *.pkg.tar.zst.sig) ]]; then
                    local file_path="${rel_path:+${rel_path}/}${name}"
                    local size
                    size="$(stat --printf='%s' "${dir}/${name}" 2>/dev/null || echo '?')"
                    if [[ "$size" != "?" ]]; then
                        size="$(numfmt --to=iec-i --suffix=B "$size")"
                    fi
                    printf '<a href="%s/%s">%s</a>%s%s\n' "$RAW_BASE" "$file_path" "$name" "$(printf '%*s' $((60 - ${#name})) '')" "$size"
                else
                    echo "<a href=\"${name}\">${name}</a>"
                fi
            fi
        done

        echo "</pre>"
        echo "</body>"
        echo "</html>"
    } > "$index_file"

    echo "Generated: ${index_file#"$REPO_ROOT"/}"
}

# Walk all directories
while IFS= read -r -d '' dir; do
    generate_index "$dir"
done < <(find "$REPO_ROOT" -type d -not -path '*/.git/*' -not -path '*/.git' -print0 | sort -z)

echo "Done."
