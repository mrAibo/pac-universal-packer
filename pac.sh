#!/usr/bin/env bash
set -euo pipefail

pac() {
    # Farbdefinitionen
    local RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC='' BOLD='' DIM=''
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && (($(tput colors 2>/dev/null || echo 0) >= 8)); then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        MAGENTA='\033[0;35m'
        NC='\033[0m'
        BOLD='\033[1m'
        DIM='\033[2m'
    fi

    local usage
    read -r -d '' usage <<'HELPTEXT' || true
${BOLD}PAC - Pack And Compress${NC}
Ein Tool für einfaches Archiv-Komprimierung und -Extraktion

${BOLD}SYNTAX${NC}
    pac [OPTIONS] file1 [file2 ...]

${BOLD}OPTIONS${NC}
    -x, --extract           Extrahier-Modus (Standard)
    -c, --compress format   Komprimier-Modus (format: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z)
    -v, --verbose           Detaillierte Ausgabe
    -t, --target dir        Zielverzeichnis angeben
    -d, --delete            Originaldatei(en) nach Operation löschen
    -e, --exclude pattern   Dateien/Verzeichnisse ausschließen
    -i, --include pattern   Dateien/Verzeichnisse einschließen
    -f, --filter file       Include/Exclude-Patterns aus Datei lesen
    -n, --name filename     Benutzerdefinierter Archivname (ohne Endung)
    --dry-run              Zeige nur was gemacht würde (ohne Ausführung)
    --no-confirm           Keine Bestätigung bei gefährlichen Operationen
    --debug                Debug-Ausgabe aktivieren
    -h, --help             Diese Hilfe anzeigen
    -l, --list             Archiv-Inhalt anzeigen
    -j, --jobs NUM         Anzahl paralleler Prozesse
    -p, --password         Verschlüsselung mit Passwort (nur zip/7z)
    -q, --quiet            Unterdrücke normale Ausgabe

${BOLD}UNTERSTÜTZTE FORMATE${NC}
    Kompression: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z
    Extraktion: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z

${BOLD}BASIC EXAMPLES${NC}
    ${DIM}# Einfache Kompression${NC}
    pac -c zip file.txt                  # Erstellt file.zip
    pac -c tar.gz directory/             # Erstellt directory.tar.gz
    
    ${DIM}# Einfache Extraktion${NC}
    pac archive.zip                      # Extrahiert ins aktuelle Verzeichnis
    pac backup.tar.gz                    # Extrahiert tar.gz Archiv

${BOLD}ADVANCED EXAMPLES${NC}
    ${DIM}# Mit Progress-Bar${NC}
    pac -c tar.gz -v large_dir/          # Zeigt Fortschritt mit pv
    
    ${DIM}# Dry-run (Test-Modus)${NC}
    pac -c zip --dry-run src/            # Zeigt nur was gemacht würde
    
    ${DIM}# Mit Bestätigung${NC}
    pac -d archive.zip                   # Fragt vor Löschen

${BOLD}SCHNELLSTART${NC}
    Ohne Argumente: Interaktiver Modus wird gestartet
    pac                                  # Startet interaktives Menü

${BOLD}TIPPS${NC}
    • Nutze ${CYAN}-v${NC} für Progress-Bar (benötigt pv)
    • Nutze ${CYAN}--dry-run${NC} zum Testen ohne Änderungen
    • Automatische Format-Erkennung beim Extrahieren
    • ${CYAN}-q${NC} für leise Ausführung in Scripts
HELPTEXT

    # Logging-Funktionen
    log_info() { 
        [[ "${quiet:-false}" != "true" ]] && echo -e "${BLUE}ℹ${NC} $*"
    }
    log_success() { 
        [[ "${quiet:-false}" != "true" ]] && echo -e "${GREEN}✓${NC} $*"
    }
    log_warning() { 
        echo -e "${YELLOW}⚠${NC} $*" >&2
    }
    log_error() { 
        echo -e "${RED}✗${NC} $*" >&2
        [[ "${quiet:-false}" != "true" ]] && echo -e "${DIM}Nutze 'pac -h' für Hilfe${NC}" >&2
    }
    log_debug() {
        [[ "${debug:-false}" == "true" ]] && echo -e "${MAGENTA}DEBUG:${NC} $*" >&2
    }

    # Progress-Funktion mit pv
    show_progress() {
        local label="$1"
        shift
        
        if command -v pv >/dev/null 2>&1 && [[ "${verbose:-false}" == "true" ]] && [[ -t 1 ]]; then
            log_info "$label"
            pv "$@"
        else
            cat "$@"
        fi
    }

    # Formatierte Dateigröße
    format_size() {
        local size=$1
        local units=("B" "KB" "MB" "GB" "TB")
        local unit=0
        local size_float=$size
        
        while (( $(echo "$size_float >= 1024" | bc -l) )) && (( unit < 4 )); do
            size_float=$(echo "scale=2; $size_float / 1024" | bc)
            ((unit++))
        done
        
        printf "%.2f %s" "$size_float" "${units[$unit]}"
    }

    # Bestätigungs-Funktion
    confirm() {
        local prompt="$1"
        local default="${2:-n}"
        
        # Überspringe wenn --no-confirm gesetzt ist
        [[ "${no_confirm:-false}" == "true" ]] && return 0
        
        local yn_prompt
        if [[ "$default" == "y" ]]; then
            yn_prompt="[Y/n]"
        else
            yn_prompt="[y/N]"
        fi
        
        read -r -p "$(echo -e "${YELLOW}?${NC} $prompt $yn_prompt ")" -n 1
        echo
        
        # Standard-Antwort wenn nur Enter gedrückt
        [[ -z "$REPLY" ]] && REPLY="$default"
        
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            return 0
        else
            log_info "Abgebrochen"
            return 1
        fi
    }

    # Interaktives Menü
    interactive_menu() {
        echo -e "${BOLD}${CYAN}PAC - Interaktiver Modus${NC}\n"
        
        PS3="$(echo -e "\n${CYAN}Wähle eine Option:${NC} ")"
        options=("Archiv erstellen" "Archiv extrahieren" "Archiv-Inhalt anzeigen" "Beenden")
        
        select opt in "${options[@]}"; do
            case $REPLY in
                1)
                    interactive_compress
                    break
                    ;;
                2)
                    interactive_extract
                    break
                    ;;
                3)
                    interactive_list
                    break
                    ;;
                4)
                    log_info "Beendet"
                    return 0
                    ;;
                *)
                    log_error "Ungültige Option"
                    ;;
            esac
        done
    }

    # Interaktive Kompression
    interactive_compress() {
        echo -e "\n${BOLD}Archiv erstellen${NC}"
        
        # Format wählen
        echo -e "\n${DIM}Verfügbare Formate:${NC}"
        local formats=("tar.gz" "tar.bz2" "tar.xz" "tar.zst" "zip" "7z" "tar")
        select format in "${formats[@]}"; do
            if [[ -n "$format" ]]; then
                compress_format="$format"
                break
            fi
        done
        
        # Dateien eingeben
        read -r -p "$(echo -e "\n${CYAN}Dateien/Verzeichnisse (Leerzeichen-getrennt):${NC} ")" -a input_files
        
        # Name eingeben
        read -r -p "$(echo -e "${CYAN}Archivname (ohne Endung):${NC} ")" custom_name
        
        # Verbose?
        if confirm "Fortschritt anzeigen?" "y"; then
            verbose=true
        fi
        
        # Nach Bestätigung komprimieren
        mode="compress"
        log_info "Starte Kompression..."
    }

    # Interaktive Extraktion
    interactive_extract() {
        echo -e "\n${BOLD}Archiv extrahieren${NC}"
        
        # Zeige verfügbare Archive
        local archives=()
        local pattern
        for pattern in "*.tar" "*.tar.gz" "*.tgz" "*.tar.bz2" "*.tbz2" "*.tar.xz" "*.txz" "*.tar.zst" "*.zip" "*.7z"; do
            while IFS= read -r file; do
                [[ -f "$file" ]] && archives+=("$file")
            done < <(compgen -G "$pattern" 2>/dev/null)
        done
        
        if [[ ${#archives[@]} -eq 0 ]]; then
            log_error "Keine Archive im aktuellen Verzeichnis gefunden"
            return 1
        fi
        
        echo -e "\n${DIM}Verfügbare Archive:${NC}"
        select archive in "${archives[@]}"; do
            if [[ -n "$archive" ]]; then
                input_files=("$archive")
                break
            fi
        done
        
        # Zielverzeichnis
        read -r -p "$(echo -e "${CYAN}Zielverzeichnis [.]:${NC} ")" target_dir
        target_dir="${target_dir:-.}"
        
        mode="extract"
        log_info "Starte Extraktion..."
    }

    # Interaktive Liste
    interactive_list() {
        echo -e "\n${BOLD}Archiv-Inhalt anzeigen${NC}"
        
        read -r -p "$(echo -e "${CYAN}Archivdatei:${NC} ")" archive
        
        if [[ ! -f "$archive" ]]; then
            log_error "Datei nicht gefunden: $archive"
            return 1
        fi
        
        input_files=("$archive")
        mode="list"
    }

    # Automatische Format-Erkennung
    detect_format() {
        local file="$1"
        case "$file" in
            *.tar.gz|*.tgz) echo "tar.gz" ;;
            *.tar.bz2|*.tbz2) echo "tar.bz2" ;;
            *.tar.xz|*.txz) echo "tar.xz" ;;
            *.tar.zst) echo "tar.zst" ;;
            *.tar) echo "tar" ;;
            *.zip) echo "zip" ;;
            *.7z) echo "7z" ;;
            *) echo "unknown" ;;
        esac
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
        
        # pv für Progress
        if ! command -v pv &>/dev/null && [[ "${verbose:-false}" == "true" ]]; then
            log_warning "pv nicht installiert - keine Progress-Anzeige verfügbar"
            log_info "Installiere mit: ${CYAN}sudo apt install pv${NC} oder ${CYAN}sudo yum install pv${NC}"
        fi
        
        # bc für Berechnungen
        if ! command -v bc &>/dev/null; then
            log_warning "bc nicht installiert - Größenberechnungen eingeschränkt"
        fi
    }

    # Validiere Eingaben
    validate_inputs() {
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Eingabedateien angegeben"
            return 1
        fi

        if [[ "$mode" == "compress" ]]; then
            for file in "${input_files[@]}"; do
                if [[ ! -e "$file" ]]; then
                    log_error "Datei/Verzeichnis nicht gefunden: $file"
                    return 1
                fi
            done
        fi

        if [[ "$mode" == "extract" || "$mode" == "list" ]]; then
            for file in "${input_files[@]}"; do
                if [[ ! -f "$file" ]]; then
                    log_error "Archiv nicht gefunden: $file"
                    return 1
                fi
            done
        fi

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

        log_debug "Lade Patterns aus: $filter_file"
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            if [[ "$line" =~ ^\\+(.+)$ ]]; then
                include_patterns+=("${BASH_REMATCH[1]}")
                log_debug "Include pattern: ${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^-(.+)$ ]]; then
                exclude_patterns+=("${BASH_REMATCH[1]}")
                log_debug "Exclude pattern: ${BASH_REMATCH[1]}"
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
    local dry_run=false
    local no_confirm=false
    local quiet=false

    # Argument-Parsing
    parse_args() {
        # Keine Argumente = Interaktiv
        if [[ $# -eq 0 ]]; then
            interactive_menu
            return 2
        fi

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
                -q|--quiet)
                    quiet=true
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
                    read -s -p "$(echo -e "${CYAN}Passwort eingeben:${NC} ")" password
                    echo
                    if [[ -z "$password" ]]; then
                        log_error "Passwort darf nicht leer sein"
                        return 1
                    fi
                    shift
                    ;;
                --dry-run)
                    dry_run=true
                    shift
                    ;;
                --no-confirm)
                    no_confirm=true
                    shift
                    ;;
                --debug)
                    debug=true
                    shift
                    ;;
                -h|--help)
                    echo -e "$usage"
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
        
        local original_size=$required_space
        
        # Realistische Kompressionsraten
        case "$compress_format" in
            tar) 
                required_space=$((required_space * 11 / 10)) ;;
            tar.gz|zip) 
                required_space=$((required_space * 7 / 10)) ;;
            tar.bz2) 
                required_space=$((required_space * 6 / 10)) ;;
            tar.xz|tar.zst) 
                required_space=$((required_space / 2)) ;;
            7z) 
                required_space=$((required_space * 4 / 10)) ;;
        esac
        
        required_space=$((required_space / 1024))
        
        local available_space
        available_space=$(df -k "$target_dir" 2>/dev/null | tail -1 | awk '{print $4}')
        
        if [[ $required_space -gt $available_space ]]; then
            log_error "Nicht genügend Speicherplatz verfügbar"
            log_error "Geschätzt benötigt: $(format_size $((required_space * 1024)))"
            log_error "Verfügbar: $(format_size $((available_space * 1024)))"
            return 1
        fi
        
        log_debug "Größe: $(format_size "$original_size") → ~$(format_size $((required_space * 1024)))"
        log_debug "Verfügbar: $(format_size $((available_space * 1024)))"
        return 0
    }

    # tar-Extraktion
    extract_tar() {
        local file="$1"
        local target="$2"
        local format="${3:-}"
        
        local tar_opts=("-x")
        
        case "$format" in
            gz) tar_opts+=("-z") ;;
            bz2) tar_opts+=("-j") ;;
            xz) tar_opts+=("-J") ;;
            zst) tar_opts+=("--zstd") ;;
        esac
        
        [[ "$verbose" == "true" ]] && tar_opts+=("-v")
        tar_opts+=("-f" "$file" "-C" "$target")
        
        log_debug "Tar-Befehl: tar ${tar_opts[*]}"
        
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${DIM}[DRY-RUN]${NC} tar ${tar_opts[*]}"
            return 0
        fi
        
        if ! tar "${tar_opts[@]}"; then
            local exit_code=$?
            log_error "Fehler beim Extrahieren von $file (Exit-Code: $exit_code)"
            return $exit_code
        fi
        
        return 0
    }

    # Build tar exclude options
    build_tar_exclude_opts() {
        local -n result_array=$1
        
        for pattern in "${exclude_patterns[@]}"; do
            result_array+=("--exclude=$pattern")
        done
        
        if [[ ${#include_patterns[@]} -gt 0 ]]; then
            log_warning "Include-Patterns werden für tar-Formate nur eingeschränkt unterstützt"
        fi
    }

    # Build zip options
    build_zip_opts() {
        local -n result_array=$1
        
        [[ "$verbose" != "true" ]] && result_array+=("-q")
        result_array+=("-r")
        
        if [[ -n "$password" ]]; then
            result_array+=("-P" "$password")
        fi
    }

    # Parse args
    parse_args "$@"
    local parse_status=$?
    
    [[ $parse_status -eq 2 ]] && return 0
    [[ $parse_status -ne 0 ]] && return 1

    [[ "$debug" == "true" ]] && set -x

    check_dependencies

    if [[ -n "$filter_file" ]]; then
        load_pattern_file "$filter_file" || return 1
    fi

    validate_inputs || return 1

    mkdir -p "$target_dir"

    local exit_code=0

    # COMPRESS MODE
    if [[ "$mode" == "compress" ]]; then
        if [[ -z "$custom_name" ]]; then
            if [[ ${#input_files[@]} -eq 1 && -e "${input_files[0]}" ]]; then
                custom_name=$(basename "${input_files[0]}")
                custom_name="${custom_name%/}"
            else
                custom_name="archive_$(date +%Y%m%d_%H%M%S)"
            fi
        fi

        local output_file
        if [[ "$target_dir" == "." ]]; then
            output_file="${custom_name}.${compress_format}"
        else
            case "$target_dir" in
                /*) output_file="${target_dir}/${custom_name}.${compress_format}" ;;
                *) output_file="$(pwd)/${target_dir}/${custom_name}.${compress_format}" ;;
            esac
        fi
        
        log_debug "Modus: $mode"
        log_debug "Ausgabedatei: $output_file"
        log_debug "Eingabedateien: ${input_files[*]}"

        check_space "${input_files[@]}" || return 1

        # Dry-run Info
        if [[ "$dry_run" == "true" ]]; then
            echo -e "\n${BOLD}${YELLOW}[DRY-RUN MODUS]${NC}"
            echo -e "${DIM}Folgende Operationen würden ausgeführt:${NC}\n"
            echo -e "  ${CYAN}Format:${NC} $compress_format"
            echo -e "  ${CYAN}Output:${NC} $output_file"
            echo -e "  ${CYAN}Dateien:${NC} ${input_files[*]}"
            [[ ${#exclude_patterns[@]} -gt 0 ]] && echo -e "  ${CYAN}Exclude:${NC} ${exclude_patterns[*]}"
            [[ ${#include_patterns[@]} -gt 0 ]] && echo -e "  ${CYAN}Include:${NC} ${include_patterns[*]}"
            echo
            return 0
        fi

        # Bestätigung für große Operationen
        if [[ "$delete_after" == "true" ]]; then
            confirm "Original-Dateien nach Kompression löschen?" "n" || return 0
        fi

        # Berechne Gesamtgröße für Progress
        local total_size=0
        if command -v du >/dev/null 2>&1; then
            for item in "${input_files[@]}"; do
                if [[ -e "$item" ]]; then
                    local item_size
                    item_size=$(du -sb "$item" 2>/dev/null | awk '{print $1}')
                    total_size=$((total_size + item_size))
                fi
            done
        fi

        log_info "Erstelle ${BOLD}$output_file${NC} $(format_size "$total_size")"

        local start_time
        start_time=$(date +%s)

        case "$compress_format" in
            tar)
                local tar_opts=("-c")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                if [[ "$verbose" == "true" ]] && command -v pv >/dev/null && [[ $total_size -gt 0 ]]; then
                    tar "${tar_opts[@]}" "${tar_exclude[@]}" "${input_files[@]}" | pv -s "$total_size" -p -t -e -r -b > "$output_file"
                    exit_code=$?
                else
                    tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                    exit_code=$?
                fi
                ;;
                
            tar.gz)
                local tar_opts=("-c" "-z")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                if [[ "$verbose" == "true" ]] && command -v pv >/dev/null && [[ $total_size -gt 0 ]]; then
                    tar "${tar_opts[@]}" "${tar_exclude[@]}" "${input_files[@]}" | pv -s "$total_size" -p -t -e -r -b > "$output_file"
                    exit_code=$?
                else
                    tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                    exit_code=$?
                fi
                ;;
                
            tar.bz2)
                local tar_opts=("-c" "-j")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                if [[ "$verbose" == "true" ]] && command -v pv >/dev/null && [[ $total_size -gt 0 ]]; then
                    tar "${tar_opts[@]}" "${tar_exclude[@]}" "${input_files[@]}" | pv -s "$total_size" -p -t -e -r -b > "$output_file"
                    exit_code=$?
                else
                    tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                    exit_code=$?
                fi
                ;;
                
            tar.xz)
                local tar_opts=("-c" "-J")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                if [[ "$verbose" == "true" ]] && command -v pv >/dev/null && [[ $total_size -gt 0 ]]; then
                    XZ_OPT="-T${jobs}" tar "${tar_opts[@]}" "${tar_exclude[@]}" "${input_files[@]}" | pv -s "$total_size" -p -t -e -r -b > "$output_file"
                    exit_code=$?
                else
                    XZ_OPT="-T${jobs}" tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                    exit_code=$?
                fi
                ;;
                
            tar.zst)
                local tar_opts=("-c" "--zstd")
                [[ "$verbose" == "true" ]] && tar_opts+=("-v")
                
                local tar_exclude=()
                build_tar_exclude_opts tar_exclude
                
                if [[ "$verbose" == "true" ]] && command -v pv >/dev/null && [[ $total_size -gt 0 ]]; then
                    ZSTD_CLEVEL="${jobs:-3}" tar "${tar_opts[@]}" "${tar_exclude[@]}" "${input_files[@]}" | pv -s "$total_size" -p -t -e -r -b > "$output_file"
                    exit_code=$?
                else
                    ZSTD_CLEVEL="${jobs:-3}" tar "${tar_opts[@]}" "${tar_exclude[@]}" -f "$output_file" "${input_files[@]}"
                    exit_code=$?
                fi
                ;;
                
            zip)
                local zip_opts=()
                build_zip_opts zip_opts
                
                if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
                    zip "${zip_opts[@]}" "$output_file" "${input_files[@]}" -x "${exclude_patterns[@]}"
                else
                    zip "${zip_opts[@]}" "$output_file" "${input_files[@]}"
                fi
                exit_code=$?
                ;;
                
            7z)
                local sz_opts=("a")
                [[ "$verbose" != "true" ]] && sz_opts+=("-bb0" "-bd")
                
                if [[ -n "$password" ]]; then
                    sz_opts+=("-p${password}" "-mhe=on")
                fi
                
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

        if [[ $exit_code -eq 0 ]]; then
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            if [[ -f "$output_file" ]]; then
                local output_size
                output_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo 0)
                local ratio
                if [[ $total_size -gt 0 ]]; then
                    ratio=$(echo "scale=1; ($output_size * 100) / $total_size" | bc 2>/dev/null || echo "?")
                else
                    ratio="?"
                fi
                
                log_success "Archiv erstellt: ${BOLD}$output_file${NC}"
                echo -e "  ${DIM}Größe: $(format_size "$output_size") (${ratio}% von original)${NC}"
                echo -e "  ${DIM}Zeit: ${duration}s${NC}"
            else
                log_success "Archiv erstellt: $output_file"
            fi
            
            if [[ "$delete_after" == "true" ]]; then
                for file in "${input_files[@]}"; do
                    if [[ -e "$file" ]]; then
                        if [[ -d "$file" ]]; then
                            rm -rf "$file" && log_debug "Verzeichnis gelöscht: $file"
                        else
                            rm -f "$file" && log_debug "Datei gelöscht: $file"
                        fi
                    fi
                done
                log_info "Original-Dateien gelöscht"
            fi
        else
            log_error "Fehler beim Erstellen des Archivs (Exit-Code: $exit_code)"
            return $exit_code
        fi
        
    # LIST MODE
    elif [[ "$mode" == "list" ]]; then
        for file in "${input_files[@]}"; do
            local format
            format=$(detect_format "$file")
            
            log_info "Inhalt von: ${BOLD}$file${NC} ${DIM}[$format]${NC}"
            
            case "$file" in
                *.tar) tar -tf "$file" || exit_code=$? ;;
                *.tar.gz|*.tgz) tar -tzf "$file" || exit_code=$? ;;
                *.tar.bz2|*.tbz2) tar -tjf "$file" || exit_code=$? ;;
                *.tar.xz|*.txz) tar -tJf "$file" || exit_code=$? ;;
                *.tar.zst) tar --zstd -tf "$file" || exit_code=$? ;;
                *.zip) unzip -l "$file" || exit_code=$? ;;
                *.7z) 7z l "$file" || exit_code=$? ;;
                *) 
                    log_error "Nicht unterstütztes Archiv: $file"
                    exit_code=1
                    ;;
            esac
            
            [[ $exit_code -ne 0 ]] && log_error "Fehler beim Auflisten von: $file"
        done
        
    # EXTRACT MODE
    else
        for file in "${input_files[@]}"; do
            local format
            format=$(detect_format "$file")
            
            if [[ "$format" == "unknown" ]]; then
                log_error "Unbekanntes Archivformat: $file"
                exit_code=1
                continue
            fi
            
            log_debug "Extrahiere: $file nach $target_dir"
            
            if [[ "$dry_run" == "true" ]]; then
                echo -e "${DIM}[DRY-RUN]${NC} Extrahiere $file → $target_dir"
                continue
            fi
            
            log_info "Extrahiere ${BOLD}$(basename "$file")${NC} → ${target_dir}"
            
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
                    [[ "$verbose" != "true" ]] && unzip_opts+=("-q")
                    
                    if [[ -n "$password" ]]; then
                        unzip "${unzip_opts[@]}" -P "$password" "$file" -d "$target_dir"
                    else
                        unzip "${unzip_opts[@]}" "$file" -d "$target_dir"
                    fi
                    exit_code=$?
                    ;;
                *.7z) 
                    local sz_opts=("x")
                    [[ "$verbose" != "true" ]] && sz_opts+=("-bb0" "-bd")
                    
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
                log_success "Extrahiert: $(basename "$file")"
                
                if [[ "$delete_after" == "true" ]]; then
                    if confirm "Original-Archiv löschen?" "n"; then
                        rm -f "$file" && log_debug "Original gelöscht: $file"
                    fi
                fi
            else
                log_error "Fehler beim Extrahieren von $file (Exit-Code: $exit_code)"
            fi
        done
    fi

    [[ "$debug" == "true" ]] && set +x

    return $exit_code
}

# Bash-Completion
_pac_autocomplete() {
    local cur prev opts formats
    
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-c --compress -x --extract -v --verbose -t --target -d --delete -n --name -e --exclude -i --include -f --filter --debug -h --help -l --list -j --jobs -p --password -q --quiet --dry-run --no-confirm"
    formats="tar tar.gz tar.bz2 tar.xz tar.zst zip 7z"
    
    local supported_archives=()
    local pattern
    for pattern in "*.tar" "*.tar.gz" "*.tgz" "*.tar.bz2" "*.tbz2" "*.tar.xz" "*.txz" "*.tar.zst" "*.zip" "*.7z"; do
        local file
        while IFS= read -r file; do
            [[ -n "$file" ]] && supported_archives+=("$file")
        done < <(compgen -G "$pattern" 2>/dev/null)
    done

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        local shortcuts="c x l"
        COMPREPLY=($(compgen -W "$opts $shortcuts" -- "$cur"))
        return 0
    fi

    case "$prev" in
        -c|--compress|c)
            COMPREPLY=($(compgen -W "$formats" -- "$cur"))
            ;;
        -x|--extract|x|-l|--list|l)
            if [[ ${#supported_archives[@]} -gt 0 ]]; then
                COMPREPLY=($(compgen -W "${supported_archives[*]}" -- "$cur"))
            else
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
        -t|--target)
            COMPREPLY=($(compgen -d -- "$cur"))
            ;;
        -e|--exclude|-i|--include|-f|--filter)
            COMPREPLY=($(compgen -f -- "$cur"))
            ;;
        -n|--name)
            COMPREPLY=("archive")
            ;;
        -j|--jobs)
            local max_jobs
            max_jobs=$(nproc 2>/dev/null || echo 8)
            COMPREPLY=($(compgen -W "$(seq 1 "$max_jobs")" -- "$cur"))
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            else
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            ;;
    esac
}

complete -F _pac_autocomplete pac
export -f pac
