#!/usr/bin/env bash
set -euo pipefail

pac() {
    # Farbdefinitionen (vereinfacht und effizienter)
    local RED='' GREEN='' YELLOW='' BLUE='' NC=''
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && (($(tput colors 2>/dev/null || echo 0) >= 8)); then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        NC='\033[0m'
    fi

    local usage
    read -r -d '' usage <<'HELPTEXT' || true
PAC - Pack And Compress
A tool for easy archive compression and extraction

SYNTAX
    pac [OPTIONS] file1 [file2 ...]

OPTIONS
    -x, --extract           Extract mode (default)
    -c, --compress format   Compress mode (format: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z)
    -v, --verbose           Show detailed progress
    -t, --target dir        Specify target directory
    -d, --delete            Delete original file(s) after operation
    -e, --exclude pattern   Exclude files/directories matching pattern
    -i, --include pattern   Include files/directories matching pattern
    -f, --filter file       Read include/exclude patterns from file
    -n, --name filename     Custom archive name (without extension)
    --debug                 Enable debug output
    -h, --help              Show this help message
    -l, --list              Zeigt den Inhalt des Archivs an
    -j, --jobs NUM          Anzahl der Prozesse für parallele Kompression
    -p, --password          Verschlüsselung mit Passwort (nur für zip und 7z)

SUPPORTED FORMATS
    Compression: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z
    Extraction: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z

BASIC EXAMPLES
    # Simple compression
    pac -c zip file.txt                  # Compress file.txt to file.zip
    pac -c tar.gz directory/             # Compress directory to directory.tar.gz
    pac -c zip src/ libs/ docs/          # archive.zip (multiple inputs)

    # Simple extraction
    pac archive.zip                      # Extract to current directory
    pac backup.tar.gz                    # Extract tar.gz archive
    pac archive1.zip archive2.tar.gz     # Extract multiple archives

ADVANCED EXAMPLES
    # Custom naming
    pac -c zip -n backup file.txt        # Creates: backup.zip
    pac -n v1.0 -c tar.gz src/           # Creates: v1.0.tar.gz
    pac src/ -c zip -n project-backup    # Creates: project-backup.zip

    # Target directory
    pac -t backups/ archive.zip          # Extract to backups/
    pac -c tar.gz -t dist/ src/          # Compress to dist/src.tar.gz
    pac -n build -c zip -t releases/ src/  # Creates: releases/build.zip

    # With file deletion
    pac -d archive.zip                   # Extract and delete archive
    pac -c zip -d src/                   # Compress and delete src/
    
    # Verbose output
    pac -v archive.tar.gz                # Show progress during extraction
    pac -v -c zip -n backup src/         # Show compression progress
    
PATTERN EXAMPLES
    # Direct patterns
    pac -c zip -e "*.tmp" src/           # Exclude .tmp files
    pac -c tar.gz -e "temp/" -e "*.log"  # Multiple excludes
    pac -i "*.txt" -i "*.pdf" -c zip docs/  # Include only specific files

    # Pattern file (patterns.txt)
    pac -c zip -f patterns.txt src/      # Use patterns from file

PATTERN FILE FORMAT
    # patterns.txt example:
    +*.txt          # Include txt files
    +*.pdf          # Include pdf files
    +src/*.java     # Include java files in src
    -*.tmp          # Exclude tmp files
    -temp/          # Exclude temp directory
    -*.log          # Exclude log files
    -build/         # Exclude build directory

COMMON USE CASES
    # Project backup
    pac -n project-backup -c zip -e "node_modules/" -e "*.log" -e "temp/" src/

    # Document archiving
    pac -c zip -i "*.pdf" -i "*.doc" -i "*.txt" -n documents docs/

    # Source code backup with cleanup
    pac -t backups/ -n src-v1.0 -c tar.gz -d -e "*.tmp" -e "build/" src/

    # Multiple directory backup
    pac -c tar.gz -n full-backup -t backups/ src/ docs/ config/

TIPS
    • All options can be specified in any order
    • Archive names are based on input names if -n is not used
    • Multiple inputs without -n create 'archive.*'
    • Use -v for detailed progress information
    • Pattern files support both include (+) and exclude (-) patterns
    • Use --debug for troubleshooting

ALIASES
    pac c format files...   Shortcut für --compress
    pac x archives...       Shortcut für --extract
    pac l archives...       Shortcut für --list
HELPTEXT

    # Logging-Funktionen
    log_info() { echo -e "${BLUE}INFO:${NC} $*"; }
    log_success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
    log_warning() { echo -e "${YELLOW}WARNING:${NC} $*" >&2; }
    log_error() { 
        echo -e "${RED}ERROR:${NC} $*" >&2
        echo "Verwende 'pac -h' für Hilfe" >&2
    }

    # Debug-Funktion
    debug_info() {
        if [[ "${debug:-false}" == "true" ]]; then
            echo -e "${YELLOW}DEBUG:${NC} $*" >&2
        fi
    }

    # Überprüfe auf notwendige Tools
    check_dependencies() {
        local missing=()
        local tools=("tar" "gzip" "bzip2" "xz" "zstd" "zip" "7z")
        
        for tool in "${tools[@]}"; do
            if ! command -v "$tool" &>/dev/null; then
                missing+=("$tool")
            fi
        done
        
        if [[ ${#missing[@]} -gt 0 ]]; then
            log_warning "Fehlende Tools: ${missing[*]}"
            log_warning "Einige Formate funktionieren möglicherweise nicht"
        fi
    }

    # Validiere Eingaben
    validate_inputs() {
        # Prüfe ob Eingabedateien vorhanden
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Eingabedateien angegeben"
            return 1
        fi

        # Prüfe ob Dateien existieren (nur im Kompressionsmodus)
        if [[ "$mode" == "compress" ]]; then
            for file in "${input_files[@]}"; do
                if [[ ! -e "$file" ]]; then
                    log_error "Datei/Verzeichnis nicht gefunden: $file"
                    return 1
                fi
            done
        fi

        # Prüfe ob Archivdateien existieren (im Extract/List Modus)
        if [[ "$mode" == "extract" || "$mode" == "list" ]]; then
            for file in "${input_files[@]}"; do
                if [[ ! -f "$file" ]]; then
                    log_error "Archiv nicht gefunden: $file"
                    return 1
                fi
            done
        fi

        # Prüfe Format-Gültigkeit
        if [[ "$mode" == "compress" ]]; then
            local valid_formats="tar tar.gz tar.bz2 tar.xz tar.zst zip 7z"
            if [[ ! " $valid_formats " =~ " $compress_format " ]]; then
                log_error "Ungültiges Format: $compress_format"
                echo "Unterstützte Formate: $valid_formats" >&2
                return 1
            fi
        fi

        return 0
    }

    # Lade Patterns aus Datei
    load_pattern_file() {
        local filter_file="$1"
        
        if [[ ! -f "$filter_file" ]]; then
            log_error "Pattern-Datei nicht gefunden: $filter_file"
            return 1
        fi

        debug_info "Lade Patterns aus: $filter_file"
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Überspringe Kommentare und Leerzeilen
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Entferne führende/nachfolgende Leerzeichen
            line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            # Parse Include/Exclude
            if [[ "$line" =~ ^\\+(.+)$ ]]; then
                include_patterns+=("${BASH_REMATCH[1]}")
                debug_info "Include pattern: ${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^-(.+)$ ]]; then
                exclude_patterns+=("${BASH_REMATCH[1]}")
                debug_info "Exclude pattern: ${BASH_REMATCH[1]}"
            else
                log_warning "Ungültige Pattern-Zeile ignoriert: $line"
            fi
        done < "$filter_file"
        
        return 0
    }

    # Standardwerte
    local mode="extract"
    local verbose=false
    local delete_after=false
    local target_dir="."
    local custom_name=""
    local compress_format=""
    local exclude_patterns=()
    local include_patterns=()
    local input_files=()
    local jobs
    jobs=$(nproc 2>/dev/null || echo 2)
    local password=""
    local debug=false
    local filter_file=""

    # Bessere Argument-Parsing-Funktion
    parse_args() {
        while [[ $# -gt 0 ]]; do
            case "$1" in
                c)
                    if [[ $# -lt 3 ]]; then
                        log_error "Format und Datei(en) für Komprimierung benötigt"
                        return 1
                    fi
                    mode="compress"
                    compress_format="$2"
                    shift 2
                    input_files=("$@")
                    return 0
                    ;;
                x)
                    mode="extract"
                    shift
                    input_files=("$@")
                    return 0
                    ;;
                l)
                    mode="list"
                    shift
                    input_files=("$@")
                    return 0
                    ;;
                -c|--compress)
                    mode="compress"
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Kompressionsformat fehlt"
                        return 1
                    fi
                    compress_format="$2"
                    shift 2
                    ;;
                -x|--extract)
                    mode="extract"
                    shift
                    ;;
                -l|--list)
                    mode="list" 
                    shift
                    ;;
                -v|--verbose)
                    verbose=true
                    shift
                    ;;
                -t|--target)
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Zielverzeichnis fehlt"
                        return 1
                    fi
                    target_dir="$2"
                    shift 2
                    ;;
                -d|--delete)
                    delete_after=true
                    shift
                    ;;
                -n|--name)
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Name fehlt"
                        return 1
                    fi
                    custom_name="$2"
                    shift 2
                    ;;
                -e|--exclude)
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Ausschlussmuster fehlt"
                        return 1
                    fi
                    exclude_patterns+=("$2")
                    shift 2
                    ;;
                -i|--include)
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Einschlussmuster fehlt"
                        return 1
                    fi
                    include_patterns+=("$2")
                    shift 2
                    ;;
                -f|--filter)
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Filterdatei fehlt"
                        return 1
                    fi
                    filter_file="$2"
                    shift 2
                    ;;
                -j|--jobs)
                    if [[ -z "${2:-}" || "$2" = -* ]]; then
                        log_error "Anzahl Jobs fehlt"
                        return 1
                    fi
                    jobs="$2"
                    shift 2
                    ;;
                -p|--password)
                    # Sicheres Passwort-Eingabe
                    read -s -p "Passwort eingeben: " password
                    echo
                    if [[ -z "$password" ]]; then
                        log_error "Passwort darf nicht leer sein"
                        return 1
                    fi
                    shift
                    ;;
                --debug)
                    debug=true
                    shift
                    ;;
                -h|--help)
                    echo "$usage"
                    return 2
                    ;;
                -*)
                    log_error "Unbekannte Option: $1"
                    return 1
                    ;;
                *)
                    input_files+=("$1")
                    shift
                    ;;
            esac
        done

        # Parameter prüfen
        if [[ "$mode" == "compress" && -z "$compress_format" ]]; then
            log_error "Kein Kompressionsformat angegeben"
            return 1
        fi

        return 0
    }

    # Speicherplatz prüfen
    check_space() {
        local required_space=0
        
        for item in "$@"; do
            if [[ -e "$item" ]]; then
                local size
                size=$(du -sb "$item" 2>/dev/null | awk '{print $1}')
                required_space=$((required_space + size))
            fi
        done
        
        # Kompressionsformat-Faktor berücksichtigen (realistischere Werte)
        case "$compress_format" in
            tar) 
                required_space=$((required_space * 11 / 10)) ;;  # +10% Overhead
            tar.gz|zip) 
                required_space=$((required_space * 7 / 10)) ;;   # ~70%
            tar.bz2) 
                required_space=$((required_space * 6 / 10)) ;;   # ~60%
            tar.xz|tar.zst) 
                required_space=$((required_space / 2)) ;;        # ~50%
            7z) 
                required_space=$((required_space * 4 / 10)) ;;   # ~40%
        esac
        
        # Konvertiere in KB für df
        required_space=$((required_space / 1024))
        
        local available_space
        available_space=$(df -k "$target_dir" 2>/dev/null | tail -1 | awk '{print $4}')
        
        if [[ $required_space -gt $available_space ]]; then
            log_error "Nicht genügend Speicherplatz verfügbar"
            log_error "Benötigt: ~${required_space}KB, Verfügbar: ${available_space}KB"
            return 1
        fi
        
        debug_info "Speicherplatz OK: ${required_space}KB benötigt, ${available_space}KB verfügbar"
        return 0
    }

    # Hilfsfunktion für tar-Extraktion
    extract_tar() {
        local file="$1"
        local target="$2"
        local format="${3:-}"
        local exit_code=0
        
        local tar_opts=("-x")
        
        # Format-spezifische Optionen hinzufügen
        case "$format" in
            gz) tar_opts+=("-z") ;;
            bz2) tar_opts+=("-j") ;;
            xz) tar_opts+=("-J") ;;
            zst) tar_opts+=("--zstd") ;;
        esac
        
        # Verbose-Option hinzufügen
        [[ "$verbose" == "true" ]] && tar_opts+=("-v")
        
        # Datei und Ziel hinzufügen
        tar_opts+=("-f" "$file" "-C" "$target")
        
        # Tar-Befehl ausführen
        debug_info "Tar-Befehl: tar ${tar_opts[*]}"
        
        if ! tar "${tar_opts[@]}"; then
            exit_code=$?
            log_error "Fehler beim Extrahieren von $file (Exit-Code: $exit_code)"
        fi
        
        return $exit_code
    }

    # Build tar exclude options
    build_tar_exclude_opts() {
        local -n result_array=$1
        
        # Exclude patterns
        for pattern in "${exclude_patterns[@]}"; do
            result_array+=("--exclude=$pattern")
        done
        
        # Include patterns (für tar nur über find möglich, hier vereinfacht)
        if [[ ${#include_patterns[@]} -gt 0 ]]; then
            log_warning "Include-Patterns werden für tar-Formate nur eingeschränkt unterstützt"
        fi
    }

    # Build zip include/exclude options
    build_zip_opts() {
        local -n result_array=$1
        
        # Basis-Optionen
        [[ "$verbose" == "true" ]] && result_array+=("-v")
        result_array+=("-r")
        
        # Passwort
        if [[ -n "$password" ]]; then
            result_array+=("-P" "$password")
        fi
    }

    # Argumente parsen
    parse_args "$@"
    local parse_status=$?
    
    # Wenn Hilfe angefordert wurde
    [[ $parse_status -eq 2 ]] && return 0
    [[ $parse_status -ne 0 ]] && return 1

    # Debug-Modus aktivieren (nach parse_args!)
    [[ "$debug" == "true" ]] && set -x

    # Dependencies prüfen
    check_dependencies

    # Pattern-Datei laden (falls angegeben)
    if [[ -n "$filter_file" ]]; then
        load_pattern_file "$filter_file" || return 1
    fi

    # Eingaben validieren
    validate_inputs || return 1

    # Verzeichnisse erstellen
    mkdir -p "$target_dir"

    # Hauptlogik
    local exit_code=0

    if [[ "$mode" == "compress" ]]; then
        # Standardmäßiger Name basierend auf Eingabedateien
        if [[ -z "$custom_name" ]]; then
            if [[ ${#input_files[@]} -eq 1 && -e "${input_files[0]}" ]]; then
                custom_name=$(basename "${input_files[0]}")
                # Entferne trailing slash
                custom_name="${custom_name%/}"
            else
                custom_name="archive_$(date +%Y%m%d_%H%M%S)"
            fi
        fi

        # Setze den vollständigen Ausgabepfad
        local output_file
        if [[ "$target_dir" == "." ]]; then
            output_file="${custom_name}.${compress_format}"
        else
            # Konvertiere zu absolutem Pfad wenn nötig
            case "$target_dir" in
                /*) 
                    output_file="${target_dir}/${custom_name}.${compress_format}" ;;
                *) 
                    output_file="$(pwd)/${target_dir}/${custom_name}.${compress_format}" ;;
            esac
        fi
        
        debug_info "Modus: $mode"
        debug_info "Zielverzeichnis: $target_dir"
        debug_info "Ausgabedatei: $output_file"
        debug_info "Eingabedateien: ${input_files[*]}"
        debug_info "Exclude-Patterns: ${exclude_patterns[*]}"
        debug_info "Include-Patterns: ${include_patterns[*]}"

        # Speicherplatz prüfen
        check_space "${input_files[@]}" || return 1

        log_info "Erstelle Archiv: $output_file"

        # Archiv erstellen
        case "$compress_format" in
            tar)
                local tar_opts=("-c")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                exit_code=$?
                ;;
                
            tar.gz)
                local tar_opts=("-c" "-z")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                exit_code=$?
                ;;
                
            tar.bz2)
                local tar_opts=("-c" "-j")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                exit_code=$?
                ;;
                
            tar.xz)
                local tar_opts=("-c" "-J")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                # Multi-Threading für xz
                XZ_OPT="-T${jobs}" tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                exit_code=$?
                ;;
                
            tar.zst)
                local tar_opts=("-c" "--zstd")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                # Multi-Threading für zstd
                ZSTD_CLEVEL="${jobs:-3}" tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                exit_code=$?
                ;;
                
            zip)
                local zip_opts=()
                build_zip_opts zip_opts
                
                # Erst Archiv erstellen, dann ggf. excludes
                if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
                    zip "${zip_opts[@]}" "$output_file" "${input_files[@]}" -x "${exclude_patterns[@]}"
                else
                    zip "${zip_opts[@]}" "$output_file" "${input_files[@]}"
                fi
                exit_code=$?
                ;;
                
            7z)
                local sz_opts=("a")
                [[ "$verbose" == "true" ]] && sz_opts+=("-v")
                
                if [[ -n "$password" ]]; then
                    sz_opts+=("-p${password}" "-mhe=on")  # Encrypt headers
                fi
                
                # Exclude patterns
                for pattern in "${exclude_patterns[@]}"; do
                    sz_opts+=("-xr!${pattern}")
                done
                
                7z "${sz_opts[@]}" "$output_file" "${input_files[@]}"
                exit_code=$?
                ;;
                
            *)
                log_error "Nicht unterstütztes Format: $compress_format"
                return 1
                ;;
        esac

        # Nach der Komprimierung
        if [[ $exit_code -eq 0 ]]; then
            log_success "Archiv erstellt: $output_file"
            
            # Lösche originale Dateien, wenn gewünscht
            if [[ "$delete_after" == "true" ]]; then
                for file in "${input_files[@]}"; do
                    if [[ -e "$file" ]]; then
                        if [[ -d "$file" ]]; then
                            rm -rf "$file" && debug_info "Verzeichnis gelöscht: $file"
                        else
                            rm -f "$file" && debug_info "Datei gelöscht: $file"
                        fi
                    fi
                done
            fi
        else
            log_error "Fehler beim Erstellen des Archivs (Exit-Code: $exit_code)"
            return $exit_code
        fi
        
    elif [[ "$mode" == "list" ]]; then
        # List mode - zeige Archiv-Inhalt
        for file in "${input_files[@]}"; do
            log_info "Inhalt von: $file"
            
            case "$file" in
                *.tar)
                    tar -tf "$file" || exit_code=$?
                    ;;
                *.tar.gz|*.tgz) 
                    tar -tzf "$file" || exit_code=$?
                    ;;
                *.tar.bz2|*.tbz2) 
                    tar -tjf "$file" || exit_code=$?
                    ;;
                *.tar.xz|*.txz) 
                    tar -tJf "$file" || exit_code=$?
                    ;;
                *.tar.zst) 
                    tar --zstd -tf "$file" || exit_code=$?
                    ;;
                *.zip) 
                    unzip -l "$file" || exit_code=$?
                    ;;
                *.7z) 
                    7z l "$file" || exit_code=$?
                    ;;
                *) 
                    log_error "Nicht unterstütztes Archiv: $file"
                    exit_code=1
                    ;;
            esac
            
            if [[ $exit_code -ne 0 ]]; then
                log_error "Fehler beim Auflisten von: $file"
            fi
        done
        
    else
        # Extract mode
        for file in "${input_files[@]}"; do
            debug_info "Extrahiere: $file nach $target_dir"
            
            case "$file" in
                *.tar)
                    extract_tar "$file" "$target_dir" ""
                    exit_code=$?
                    ;;
                *.tar.gz|*.tgz) 
                    extract_tar "$file" "$target_dir" "gz"
                    exit_code=$?
                    ;;
                *.tar.bz2|*.tbz2) 
                    extract_tar "$file" "$target_dir" "bz2"
                    exit_code=$?
                    ;;
                *.tar.xz|*.txz) 
                    extract_tar "$file" "$target_dir" "xz"
                    exit_code=$?
                    ;;
                *.tar.zst) 
                    extract_tar "$file" "$target_dir" "zst"
                    exit_code=$?
                    ;;
                *.zip) 
                    local unzip_opts=()
                    [[ "$verbose" == "true" ]] && unzip_opts+=("-v")
                    
                    if [[ -n "$password" ]]; then
                        unzip "${unzip_opts[@]}" -P "$password" "$file" -d "$target_dir"
                    else
                        unzip "${unzip_opts[@]}" "$file" -d "$target_dir"
                    fi
                    exit_code=$?
                    ;;
                *.7z) 
                    local sz_opts=("x")
                    [[ "$verbose" == "true" ]] && sz_opts+=("-v")
                    
                    if [[ -n "$password" ]]; then
                        sz_opts+=("-p${password}")
                    fi
                    
                    sz_opts+=("$file" "-o${target_dir}")
                    7z "${sz_opts[@]}"
                    exit_code=$?
                    ;;
                *) 
                    log_error "Nicht unterstütztes Archiv: $file"
                    exit_code=1
                    ;;
            esac
            
            if [[ $exit_code -eq 0 ]]; then
                log_success "Extrahiert: $file"
                
                if [[ "$delete_after" == "true" && -f "$file" ]]; then
                    rm -f "$file" && debug_info "Original gelöscht: $file"
                fi
            else
                log_error "Fehler beim Extrahieren von $file (Exit-Code: $exit_code)"
            fi
        done
    fi

    # Debug-Modus deaktivieren
    [[ "$debug" == "true" ]] && set +x

    return $exit_code
}

# Bash-Completion
_pac_autocomplete() {
    local cur prev opts formats
    
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-c --compress -x --extract -v --verbose -t --target -d --delete -n --name -e --exclude -i --include -f --filter --debug -h --help -l --list -j --jobs -p --password"
    formats="tar tar.gz tar.bz2 tar.xz tar.zst zip 7z"
    
    # Generiere unterstützte Archivdateien
    local supported_archives=()
    local pattern
    for pattern in "*.tar" "*.tar.gz" "*.tgz" "*.tar.bz2" "*.tbz2" "*.tar.xz" "*.txz" "*.tar.zst" "*.zip" "*.7z"; do
        local file
        while IFS= read -r file; do
            [[ -n "$file" ]] && supported_archives+=("$file")
        done < <(compgen -G "$pattern" 2>/dev/null)
    done

    # Erstes Argument - Shortcuts oder Optionen
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local shortcuts="c x l"
        COMPREPLY=($(compgen -W "$opts $shortcuts" -- "$cur"))
        return 0
    fi

    # Kontext-basierte Vervollständigung
    case "$prev" in
        -c|--compress|c)
            COMPREPLY=($(compgen -W "$formats" -- "$cur"))
            return 0
            ;;
        -x|--extract|x)
            if [[ ${#supported_archives[@]} -gt 0 ]]; then
                COMPREPLY=($(compgen -W "${supported_archives[*]}" -- "$cur"))
            else
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            return 0
            ;;
        -l|--list|l)
            if [[ ${#supported_archives[@]} -gt 0 ]]; then
                COMPREPLY=($(compgen -W "${supported_archives[*]}" -- "$cur"))
            else
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            return 0
            ;;
        -t|--target)
            COMPREPLY=($(compgen -d -- "$cur"))
            return 0
            ;;
        -e|--exclude|-i|--include|-f|--filter)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
        -n|--name)
            COMPREPLY=("archive")
            return 0
            ;;
        -j|--jobs)
            local max_jobs
            max_jobs=$(nproc 2>/dev/null || echo 8)
            COMPREPLY=($(compgen -W "$(seq 1 "$max_jobs")" -- "$cur"))
            return 0
            ;;
        -p|--password)
            COMPREPLY=()
            return 0
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            else
                # Datei/Verzeichnis-Vervollständigung
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            return 0
            ;;
    esac
}

# Aktiviere Bash-Completion
complete -F _pac_autocomplete pac

# Exportiere Funktion (optional, für Subshells)
export -f pac
