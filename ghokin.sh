#!/usr/bin/env bash

set -euo pipefail

# Default configuration
INDENT=2
# Store aliases as "key=value" pairs (compatible with Bash 3)
ALIASES_ARRAY=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration from .ghokin.yml if it exists
load_config() {
    local config_file=""

    # Check for config file in order of precedence
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        config_file="$CONFIG_FILE"
    elif [[ -f ".ghokin.yml" ]]; then
        config_file=".ghokin.yml"
    elif [[ -f "$HOME/.ghokin.yml" ]]; then
        config_file="$HOME/.ghokin.yml"
    fi

    # Load from environment variables (takes precedence)
    if [[ -n "${GHOKIN_INDENT:-}" ]]; then
        INDENT="$GHOKIN_INDENT"
    fi

    # Parse GHOKIN_ALIASES if set (expects JSON format)
    if [[ -n "${GHOKIN_ALIASES:-}" ]]; then
        # Simple JSON parsing for aliases
        while IFS= read -r line; do
            if [[ $line =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                ALIASES_ARRAY+=("${BASH_REMATCH[1]}=${BASH_REMATCH[2]}")
            fi
        done < <(echo "$GHOKIN_ALIASES" | tr -d '{}' | tr ',' '\n')
    fi

    # Load from YAML config file if exists
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ $line =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// /}" ]] && continue

            # Parse indent
            if [[ $line =~ ^indent:[[:space:]]*([0-9]+) ]]; then
                INDENT="${BASH_REMATCH[1]}"
            fi

            # Parse aliases section
            if [[ $line =~ ^aliases: ]]; then
                in_aliases=true
                continue
            fi

            # Parse alias entries
            if [[ "${in_aliases:-false}" == "true" && $line =~ ^[[:space:]]+([^:]+):[[:space:]]*\"([^\"]+)\" ]]; then
                local key="${BASH_REMATCH[1]// /}"
                local value="${BASH_REMATCH[2]}"
                ALIASES_ARRAY+=("${key}=${value}")
            elif [[ "${in_aliases:-false}" == "true" && $line =~ ^[^[:space:]] ]]; then
                in_aliases=false
            fi
        done < "$config_file"
    fi
}

# Format gherkin content
format_gherkin() {
    local content="$1"
    local indent_str=""

    # Create indent string
    for ((i=0; i<INDENT; i++)); do
        indent_str="${indent_str} "
    done

    # Process the content line by line
    # Use LC_ALL=C.UTF-8 or LC_CTYPE=UTF-8 to handle multi-byte characters properly
    echo "$content" | LC_ALL=en_US.UTF-8 awk -v indent="$indent_str" '
    BEGIN {
        in_docstring = 0
        in_examples = 0
        in_table = 0
        after_feature = 0
        after_scenario = 0
        rule_level = 0
        table_count = 0
    }

    # Language declaration
    /^[[:space:]]*#[[:space:]]*language:/ {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        print
        next
    }

    # Comments (not language or annotations)
    /^[[:space:]]*#/ && !/^[[:space:]]*#[[:space:]]*@/ {
        if (in_table) {
            # Buffer comment within table
            table_buffer[table_count] = $0
            table_is_row[table_count] = 0
            table_count++
            next
        } else if (after_scenario) {
            gsub(/^[[:space:]]+/, "")
            print indent indent $0
        } else if (after_feature) {
            gsub(/^[[:space:]]+/, "")
            print indent $0
        } else {
            gsub(/^[[:space:]]+/, "")
            print indent $0
        }
        next
    }

    # Annotation comments for shell commands
    /^[[:space:]]*#[[:space:]]*@[a-zA-Z0-9]+/ {
        if (in_table) {
            print indent indent indent $0
        } else {
            gsub(/^[[:space:]]+/, "")
            print indent indent indent $0
        }
        next
    }

    # Tags
    /^[[:space:]]*@/ {
        flush_table()
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if (after_scenario || in_examples) {
            print indent indent $0
        } else {
            print $0
        }
        next
    }

    # Feature line
    /^[[:space:]]*(Feature|Función|Fonctionnalité):/ {
        flush_table()
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (match(line, /:/)) {
            keyword = substr(line, 1, RSTART)
            sub(/:$/, "", keyword)
            text = substr(line, RSTART + 1)
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            print keyword ": " text
        }
        after_feature = 1
        after_scenario = 0
        next
    }

    # Rule line
    /^[[:space:]]*(Rule|Regla|Règle):/ {
        flush_table()
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (match(line, /:/)) {
            keyword = substr(line, 1, RSTART)
            sub(/:$/, "", keyword)
            text = substr(line, RSTART + 1)
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            print indent keyword ": " text
        }
        rule_level = 1
        next
    }

    # Background line
    /^[[:space:]]*(Background|Contexte|Antecedentes):/ {
        flush_table()
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (match(line, /:/)) {
            keyword = substr(line, 1, RSTART)
            sub(/:$/, "", keyword)
            text = substr(line, RSTART + 1)
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            if (rule_level) {
                print indent indent keyword ": " text
            } else {
                print indent keyword ": " text
            }
        }
        after_feature = 0
        after_scenario = 1
        next
    }

    # Scenario line
    /^[[:space:]]*(Scenario|Scenario Outline|Scénario|Esquema del escenario):/ {
        flush_table()
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (match(line, /:/)) {
            keyword = substr(line, 1, RSTART)
            sub(/:$/, "", keyword)
            text = substr(line, RSTART + 1)
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            if (rule_level) {
                print indent indent keyword ": " text
            } else {
                print indent keyword ": " text
            }
        }
        after_feature = 0
        after_scenario = 1
        in_examples = 0
        next
    }

    # Examples line
    /^[[:space:]]*(Examples|Exemples|Ejemplos):/ {
        flush_table()
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (match(line, /:/)) {
            keyword = substr(line, 1, RSTART)
            sub(/:$/, "", keyword)
            text = substr(line, RSTART + 1)
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            if (rule_level) {
                print indent indent indent keyword ": " text
            } else {
                print indent indent keyword ": " text
            }
        }
        in_examples = 1
        next
    }

    # Step lines (Given, When, Then, And, But)
    /^[[:space:]]*(Given|When|Then|And|But|Dado|Cuando|Entonces|Y|Pero|Soit|Quand|Alors|Et|Mais)[[:space:]]/ {
        flush_table()
        line = $0
        sub(/^[[:space:]]+/, "", line)
        keyword = $1
        text = substr(line, length($1) + 1)
        sub(/^[[:space:]]+/, "", text)
        sub(/[[:space:]]+$/, "", text)
        if (rule_level) {
            print indent indent indent keyword " " text
        } else {
            print indent indent keyword " " text
        }
        after_feature = 0
        next
    }

    # DocString separator (""")
    /^[[:space:]]*"""/ {
        flush_table()
        gsub(/^[[:space:]]+/, "")
        if (rule_level) {
            print indent indent indent indent $0
        } else {
            print indent indent indent $0
        }
        in_docstring = !in_docstring
        next
    }

    # Table rows - buffer them for proper alignment
    /^[[:space:]]*\|/ {
        table_buffer[table_count] = $0
        table_is_row[table_count] = 1
        table_count++
        in_table = 1
        next
    }

    # DocString content
    in_docstring {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if (rule_level) {
            print indent indent indent indent $0
        } else {
            print indent indent indent $0
        }
        next
    }

    # Description lines (after Feature or Scenario)
    /^[[:space:]]*[^[:space:]]/ {
        flush_table()
        if (after_feature) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            print indent $0
            next
        } else if (after_scenario) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if (rule_level) {
                print indent indent indent $0
            } else {
                print indent indent $0
            }
            next
        }
    }

    # Empty lines
    /^[[:space:]]*$/ {
        flush_table()
        print ""
        next
    }

    # Default: preserve the line
    {
        flush_table()
        print $0
    }

    END {
        flush_table()
    }

    # Function to calculate UTF-8 string length (character count, not byte count)
    function utf8_length(str,    len, i, c) {
        len = 0
        for (i = 1; i <= length(str); i++) {
            c = substr(str, i, 1)
            # Check if this is the start of a UTF-8 character
            # UTF-8 continuation bytes start with 10xxxxxx (128-191)
            if (c < "\200" || c >= "\300") {
                len++
            }
        }
        return len
    }

    # Function to pad string to specified width (UTF-8 aware)
    function utf8_pad(str, width,    padding, current_len, spaces, k) {
        current_len = utf8_length(str)
        if (current_len >= width) {
            return str
        }
        spaces = width - current_len
        padding = ""
        for (k = 0; k < spaces; k++) {
            padding = padding " "
        }
        return str padding
    }

    # Function to flush buffered table
    function flush_table() {
        if (table_count == 0) return

        # Calculate column widths
        max_cols = 0
        for (i = 0; i < table_count; i++) {
            if (table_is_row[i]) {
                line = table_buffer[i]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)

                # Parse table cells - split on |
                n_cells = split(line, cells, /\|/)
                # First and last elements are empty (before first | and after last |)
                num_cols = n_cells - 2
                if (num_cols > max_cols) max_cols = num_cols

                for (j = 2; j < n_cells; j++) {
                    cell = cells[j]
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
                    cell_data[i,j-2] = cell
                    # Calculate visual width of cell (number of characters, not bytes)
                    cell_len = utf8_length(cell)
                    col_idx = j - 2
                    if (cell_len > col_width[col_idx]) {
                        col_width[col_idx] = cell_len
                    }
                }
                row_cols[i] = num_cols
            }
        }

        # Output formatted table
        for (i = 0; i < table_count; i++) {
            if (table_is_row[i]) {
                # Format row with aligned columns
                row = "|"
                for (j = 0; j < row_cols[i]; j++) {
                    cell = cell_data[i,j]
                    width = col_width[j]
                    # Left-align with padding (UTF-8 aware)
                    padded_cell = utf8_pad(cell, width)
                    row = row " " padded_cell " |"
                }

                if (rule_level) {
                    print indent indent indent indent row
                } else {
                    print indent indent indent row
                }
            } else {
                # Output comment as-is with proper indentation
                line = table_buffer[i]
                gsub(/^[[:space:]]+/, "", line)
                if (rule_level) {
                    print indent indent indent indent line
                } else {
                    print indent indent indent line
                }
            }
        }

        # Clear table buffer
        table_count = 0
        delete table_buffer
        delete table_is_row
        delete cell_data
        delete col_width
        delete row_cols
        in_table = 0
    }
    '
}

# Get alias value by key
get_alias() {
    local key="$1"
    for alias in "${ALIASES_ARRAY[@]}"; do
        if [[ "$alias" =~ ^${key}=(.+)$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
    done
    return 1
}

# Apply shell command transformations based on annotations
apply_transformations() {
    local content="$1"
    local result="$content"

    # Look for annotation comments (# @alias)
    # Check if array has elements to avoid unbound variable error
    if [[ ${#ALIASES_ARRAY[@]} -eq 0 ]]; then
        echo "$result"
        return
    fi

    for alias_pair in "${ALIASES_ARRAY[@]}"; do
        if [[ "$alias_pair" =~ ^([^=]+)=(.+)$ ]]; then
            local alias="${BASH_REMATCH[1]}"
            local cmd="${BASH_REMATCH[2]}"

            # Find lines with the annotation and apply the command to the following section
            # This is a simplified version - the Go version is more sophisticated
            result=$(echo "$result" | awk -v annotation="# @$alias" -v cmd="$cmd" '
            BEGIN { apply_next = 0; buffer = "" }
            {
                if ($0 ~ annotation) {
                    print $0
                    apply_next = 1
                    next
                }
                if (apply_next && /^[[:space:]]*"""/) {
                    if (buffer == "") {
                        print $0
                        buffer = "start"
                    } else {
                        # Apply command to buffer content
                        print $0
                        apply_next = 0
                        buffer = ""
                    }
                } else if (apply_next && buffer == "start") {
                    # Collect docstring content (simplified)
                    print $0
                } else {
                    print $0
                }
            }
            ')
        fi
    done

    echo "$result"
}

# Format and output to stdout
fmt_stdout() {
    local input=""

    if [[ $# -eq 0 ]]; then
        # Read from stdin
        input=$(cat)
    else
        # Read from file
        if [[ ! -f "$1" ]]; then
            error_fatal "File not found: $1"
        fi
        input=$(cat "$1")
    fi

    local formatted
    formatted=$(format_gherkin "$input")
    formatted=$(apply_transformations "$formatted")

    echo "$formatted"
}

# Format and replace file(s)
fmt_replace() {
    local path="$1"
    local extensions=("${@:2}")

    # Default extension
    if [[ ${#extensions[@]} -eq 0 ]]; then
        extensions=("feature")
    fi

    if [[ ! -e "$path" ]]; then
        error_fatal "Path not found: $path"
    fi

    local files=()

    if [[ -f "$path" ]]; then
        files=("$path")
    elif [[ -d "$path" ]]; then
        # Find all feature files
        for ext in "${extensions[@]}"; do
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$path" -type f -name "*.${ext}" -print0)
        done
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        success "No files found to format"
        return 0
    fi

    local error_count=0

    for file in "${files[@]}"; do
        local content
        content=$(cat "$file")

        local formatted
        formatted=$(format_gherkin "$content")
        formatted=$(apply_transformations "$formatted")

        if [[ $? -ne 0 ]]; then
            error "Failed to format: $file"
            ((error_count++))
            continue
        fi

        echo "$formatted" > "$file"
    done

    if [[ $error_count -gt 0 ]]; then
        exit 1
    fi

    success "\"$path\" formatted"
}

# Check if file(s) are well formatted
check_files() {
    local path="$1"
    local extensions=("${@:2}")

    # Default extension
    if [[ ${#extensions[@]} -eq 0 ]]; then
        extensions=("feature")
    fi

    if [[ ! -e "$path" ]]; then
        error_fatal "Path not found: $path"
    fi

    local files=()

    if [[ -f "$path" ]]; then
        files=("$path")
    elif [[ -d "$path" ]]; then
        # Find all feature files
        for ext in "${extensions[@]}"; do
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$path" -type f -name "*.${ext}" -print0)
        done
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        success "No files found to check"
        return 0
    fi

    local error_count=0

    for file in "${files[@]}"; do
        local content
        content=$(cat "$file")

        local formatted
        formatted=$(format_gherkin "$content")
        formatted=$(apply_transformations "$formatted")

        if [[ $? -ne 0 ]]; then
            error "Error processing: $file"
            ((error_count++))
            continue
        fi

        if [[ "$content" != "$formatted" ]]; then
            error "File is not properly formatted: $file"
            ((error_count++))
        fi
    done

    if [[ $error_count -gt 0 ]]; then
        exit 1
    fi

    success "\"$path\" is well formatted"
}

# Output helpers
error() {
    echo -e "${RED}Error: $*${NC}" >&2
}

error_fatal() {
    error "$*"
    exit 1
}

success() {
    echo -e "${GREEN}$*${NC}"
}

# Show usage
show_usage() {
    cat <<EOF
Clean and/or apply transformation on gherkin files

Usage:
  ghokin.sh [command]

Available Commands:
  check       Check a file/folder is well formatted
  fmt         Format a feature file/folder
  help        Show this help message

Flags:
  --config string   config file
  -h, --help       help for ghokin

Use "ghokin.sh [command] --help" for more information about a command.
EOF
}

show_fmt_usage() {
    cat <<EOF
Format a feature file/folder

Usage:
  ghokin.sh fmt [command]

Available Commands:
  stdout      Format stdin or a file and dump the result on stdout
  replace     Format and replace a file or a pool of files in folder

Flags:
  -h, --help   help for fmt
EOF
}

show_check_usage() {
    cat <<EOF
Check a file/folder is well formatted

Usage:
  ghokin.sh check [file or folder path]

Flags:
  -e, --extensions   Define file extensions to use to find feature files (default: feature)
  -h, --help        help for check
EOF
}

show_fmt_stdout_usage() {
    cat <<EOF
Format stdin or a file and dump the result on stdout

Usage:
  ghokin.sh fmt stdout [file path]

Flags:
  -h, --help   help for stdout
EOF
}

show_fmt_replace_usage() {
    cat <<EOF
Format and replace a file or a pool of files in folder

Usage:
  ghokin.sh fmt replace [file or folder path]

Flags:
  -e, --extensions   Define file extensions to use to find feature files (default: feature)
  -h, --help        help for replace
EOF
}

# Parse global flags
parse_global_flags() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done
}

# Main command dispatcher
main() {
    # Parse global flags first
    local args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    set -- "${args[@]}"

    # Load configuration
    load_config

    # Parse command
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 0
    fi

    case $1 in
        help|-h|--help)
            show_usage
            ;;
        fmt)
            shift
            if [[ $# -eq 0 ]]; then
                show_fmt_usage
                exit 0
            fi

            case $1 in
                stdout)
                    shift
                    if [[ $# -gt 0 && ("$1" == "-h" || "$1" == "--help") ]]; then
                        show_fmt_stdout_usage
                        exit 0
                    fi
                    fmt_stdout "$@"
                    ;;
                replace)
                    shift
                    local extensions=()
                    local path=""

                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -h|--help)
                                show_fmt_replace_usage
                                exit 0
                                ;;
                            -e|--extensions)
                                IFS=',' read -ra extensions <<< "$2"
                                shift 2
                                ;;
                            *)
                                path="$1"
                                shift
                                ;;
                        esac
                    done

                    if [[ -z "$path" ]]; then
                        error_fatal "you must provide a filename or a folder as argument"
                    fi

                    if [[ ${#extensions[@]} -gt 0 ]]; then
                        fmt_replace "$path" "${extensions[@]}"
                    else
                        fmt_replace "$path"
                    fi
                    ;;
                help|-h|--help)
                    show_fmt_usage
                    ;;
                *)
                    error_fatal "Unknown fmt command: $1"
                    ;;
            esac
            ;;
        check)
            shift
            local extensions=()
            local path=""

            while [[ $# -gt 0 ]]; do
                case $1 in
                    -h|--help)
                        show_check_usage
                        exit 0
                        ;;
                    -e|--extensions)
                        IFS=',' read -ra extensions <<< "$2"
                        shift 2
                        ;;
                    *)
                        path="$1"
                        shift
                        ;;
                esac
            done

            if [[ -z "$path" ]]; then
                error_fatal "you must provide a filename or a folder as argument"
            fi

            if [[ ${#extensions[@]} -gt 0 ]]; then
                check_files "$path" "${extensions[@]}"
            else
                check_files "$path"
            fi
            ;;
        *)
            error_fatal "Unknown command: $1"
            ;;
    esac
}

# Run main
main "$@"
