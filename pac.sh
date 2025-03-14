pac() {
    # Farbdefinitionen
    local use_color=$([[ -t 1 && "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]] && echo 1 || echo 0)
    local RED=$([[ $use_color -eq 1 ]] && echo '\033[0;31m' || echo '')
    local GREEN=$([[ $use_color -eq 1 ]] && echo '\033[0;32m' || echo '')
    local YELLOW=$([[ $use_color -eq 1 ]] && echo '\033[0;33m' || echo '')
    local BLUE=$([[ $use_color -eq 1 ]] && echo '\033[0;34m' || echo '')
    local NC=$([[ $use_color -eq 1 ]] && echo '\033[0m' || echo '')

    local usage
    read -r -d '' usage <<'HELPTEXT'
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
    -j, --jobs NUM         Anzahl der Prozesse für parallele Kompression
    -p, --password PASS    Verschlüsselung mit Passwort (nur für zip und 7z)

SUPPORTED FORMATS
    Compression: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z
    Extraction: tar, tar.gz, tar.bz2, tar.xz, tar.zst, zip, 7z

BASIC EXAMPLES
	# Simple compression (creates named_output.format)
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
    pac x archives...       Shortcut für Extrahieren
    pac l archives...       Shortcut für --list
HELPTEXT

    # Logging-Funktionen
    log_info() { echo -e "${BLUE}INFO:${NC} $*"; }
    log_success() { echo -e "${GREEN}SUCCESS:${NC} $*"; }
    log_warning() { echo -e "${YELLOW}WARNING:${NC} $*" >&2; }
    log_error() { echo -e "${RED}ERROR:${NC} $*" >&2; }

    # Überprüfe auf notwendige Tools
    check_dependencies() {
        local tools=("tar" "gzip" "bzip2" "xz" "zstd" "zip" "7z" "pv")
        for tool in "${tools[@]}"; do
            if ! command -v "$tool" &>/dev/null; then
                log_warning "$tool is not installed. Some formats may not work."
            fi
        done
    }
	
    # Debug-Modus
    local debug=false

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
    local jobs=$(nproc 2>/dev/null || echo 2)  # Fallback auf 2 Threads, wenn nproc nicht verfügbar
    local password=""

    # Füge diese Diagnose-Funktion am Anfang der pac-Funktion hinzu
    debug_info() {
        if [[ "$debug" == "true" ]]; then
            echo "DEBUG: $*"
        fi
    }

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
                    # Rest sind Eingabedateien
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
                    if [[ -z "$2" || "$2" = -* ]]; then
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
                    if [[ -z "$2" || "$2" = -* ]]; then
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
                    if [[ -z "$2" || "$2" = -* ]]; then
                        log_error "Name fehlt"
                        return 1
                    fi
                    custom_name="$2"
                    shift 2
                    ;;
                -e|--exclude)
                    if [[ -z "$2" || "$2" = -* ]]; then
                        log_error "Ausschlussmuster fehlt"
                        return 1
                    fi
                    exclude_patterns+=("$2")
                    shift 2
                    ;;
                -i|--include)
                    if [[ -z "$2" || "$2" = -* ]]; then
                        log_error "Einschlussmuster fehlt"
                        return 1
                    fi
                    include_patterns+=("$2")
                    shift 2
                    ;;
                -f|--filter)
                    if [[ -z "$2" || "$2" = -* ]]; then
                        log_error "Filterdatei fehlt"
                        return 1
                    fi
                    filter_file="$2"
                    shift 2
                    ;;
                -j|--jobs)
                    if [[ -z "$2" || "$2" = -* ]]; then
                        log_error "Anzahl Jobs fehlt"
                        return 1
                    fi
                    jobs="$2"
                    shift 2
                    ;;
                -p|--password)
                    if [[ -z "$2" || "$2" = -* ]]; then
                        log_error "Passwort fehlt"
                        return 1
                    fi
                    password="$2"
                    shift 2
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

    # Debugging aktivieren
    $debug && set -x

    # Argumente parsen
    parse_args "$@"
    local parse_status=$?
    
    # Wenn Hilfe angefordert wurde oder Parse-Fehler
    [[ $parse_status -eq 2 ]] && return 0
    [[ $parse_status -ne 0 ]] && return 1

    # Verzeichnisse erstellen
    mkdir -p "$target_dir"

    # Stellen sicher, dass output_file den absoluten Pfad enthält
    if [[ "$target_dir" != "." && "$target_dir" != "" ]]; then
        case "$target_dir" in
            /*) # Absoluter Pfad
                output_file="${target_dir}/${custom_name}.${compress_format}" ;;
            *) # Relativer Pfad
                output_file="$(pwd)/${target_dir}/${custom_name}.${compress_format}" ;;
        esac
    else
        output_file="${custom_name}.${compress_format}"
    fi

    # Log für Debugging
    debug_info "Finaler Ausgabepfad: $output_file"

    # Hilfsfunktion für tar-Extraktion
    extract_tar() {
        local file=$1
        local target=$2
        local format=$3
        local exit_code=0
        
        local tar_opts=("-x")
        # Format-spezifische Optionen hinzufügen
        case "$format" in
            "gz") tar_opts+=("-z") ;;
            "bz2") tar_opts+=("-j") ;;
            "xz") tar_opts+=("-J") ;;
            "zst") tar_opts+=("--zstd") ;;
        esac
        
        # Verbose-Option hinzufügen, wenn aktiviert
        [[ "$verbose" == "true" ]] && tar_opts+=("-v")
        
        # Datei und Ziel hinzufügen
        tar_opts+=("-f" "$file" "-C" "$target")
        
        # Tar-Befehl ausführen
        debug_info "Tar-Befehl: tar ${tar_opts[*]}"
        tar "${tar_opts[@]}" || {
            exit_code=$?
            log_error "Fehler beim Extrahieren von $file (Code: $exit_code)"
        }
        
        return $exit_code
    }
    
    # Hauptlogik
    if [[ "$mode" == "compress" ]]; then
        # Prüfe ob Eingabedateien vorhanden
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Eingabedateien angegeben"
            return 1
        fi

        # Standardmäßiger Name basierend auf Eingabedateien
        if [[ -z "$custom_name" ]]; then
            if [[ ${#input_files[@]} -eq 1 && -e "${input_files[0]}" ]]; then
                # Nur Basisdateinamen nehmen
                custom_name="$(basename "${input_files[0]}")"
            else
                custom_name="archive_$(date +%Y%m%d_%H%M%S)"
            fi
        fi

        # Setze den vollständigen Ausgabepfad
        local output_file="${target_dir}/${custom_name}.${compress_format}"
        
        # Debug-Ausgabe
        debug_info "Modus: $mode"
        debug_info "Zielverzeichnis: $target_dir"
        debug_info "Ausgabedatei: $output_file"
        debug_info "Eingabedateien: ${input_files[*]}"

        # Speicherplatz prüfen
        check_space "${input_files[@]}" || return 1

        echo "Erstelle Archiv: $output_file"

        # Bestimme die Archiv-Operation
        case "$compress_format" in
            tar)
                # Einfache tar-Kompression ohne zusätzliche Kompression
                tar -c${verbose:+v}f "$output_file" "${input_files[@]}"
                ;;
            tar.gz)
                # Wichtig: Kein Leerzeichen zwischen Parametern und -f!
                tar -cz${verbose:+v}f "$output_file" "${input_files[@]}"
                ;;
            tar.bz2)
                tar -cj${verbose:+v}f "$output_file" "${input_files[@]}"
                ;;
            tar.xz)
                # Multi-Threading mit allen Kernen als Standard
                XZ_OPT="-T${jobs}" tar -cJ${verbose:+v}f "$output_file" "${input_files[@]}"
                ;;
            tar.zst)
                ZSTD_CLEVEL="${jobs:-3}" tar --zstd -c${verbose:+v}f "$output_file" "${input_files[@]}"
                ;;
            zip)
                zip_opts=()
                [[ "$verbose" == "true" ]] && zip_opts+=("-v")
                zip_opts+=("-r")
                
                # Ausschlussmuster ohne Anführungszeichen verwenden
                # (zip benötigt spezielle Syntax für Ausschlussmuster)
                if [[ ${#exclude_patterns[@]} -gt 0 ]]; then
                    # Füge Ausschlussmuster ohne Anführungszeichen hinzu (wichtig!)
                    # Syntax: -x PATTERN
                    for pattern in "${exclude_patterns[@]}"; do
                        zip_opts+=(-x "${pattern}")
                    done
                fi
                
                # Debug-Info
                debug_info "Zip-Befehl-Optionen: ${zip_opts[*]}"
                debug_info "Ausgabedatei: $output_file"
                debug_info "Eingabedateien: ${input_files[*]}"
                
                zip "${zip_opts[@]}" "$output_file" "${input_files[@]}"
                ;;
            7z)
                local sz_opts=("a")
                if [[ -n "$password" ]]; then
                    sz_opts+=("-p$password")
                fi
                7z "${sz_opts[@]}" "$output_file" "${input_files[@]}"
                ;;
            *)
                log_error "Unsupported format: $compress_format"
                return 1
                ;;
        esac

        # Nach der Komprimierung
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            log_success "Archive created: $output_file"
            
            # Lösche originale Dateien, wenn gewünscht
            if [[ "$delete_after" == "true" ]]; then
                for file in "${input_files[@]}"; do
                    if [[ -e "$file" ]]; then
                        # Verwende rm -f damit keine Nachfrage kommt
                        if [[ -d "$file" ]]; then
                            rm -rf "$file" && debug_info "Deleted original directory: $file"
                        else
                            rm -f "$file" && debug_info "Deleted original file: $file"
                        fi
                    fi
                done
            fi
        else
            log_error "Fehler beim Erstellen des Archivs"
            return $exit_code
        fi
    elif [[ "$mode" == "list" ]]; then
        # List mode logic
        local exit_code=0
        for file in "${input_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                log_error "Archiv nicht gefunden: $file"
                exit_code=1
                continue
            fi
            
            log_info "Inhalt von: $file"
            case "$file" in
                *.tar)
                    tar -tf "$file" ;;
                *.tar.gz|*.tgz) 
                    tar -tzf "$file" ;;
                *.tar.bz2|*.tbz2) 
                    # Extrahiere in das gleiche Verzeichnis wie das Target
                    mkdir -p "$target_dir"
                    
                    # Verzeichnis der Subdatei erstellen
                    mkdir -p "$target_dir/subdir"
                    
                    # Mit -C und korrekten Pfadkomponenten
                    tar_opts=("-xjf")
                    [[ "$verbose" == "true" ]] && tar_opts=("-xvjf")
                    tar "${tar_opts[@]}" "$file" -C "$target_dir" || {
                        exit_code=$?
                        log_error "Fehler beim Extrahieren von $file (Code: $exit_code)"
                    }
                    ;;
                *.tar.xz|*.txz) 
                    tar_opts=("-xf")
                    [[ "$verbose" == "true" ]] && tar_opts=("-xvf")
                    tar "${tar_opts[@]}" "$file" -C "$target_dir" || {
                        exit_code=$?
                        log_error "Fehler beim Extrahieren von $file (Code: $exit_code)"
                    }
                    ;;
                *.tar.zst) 
                    tar_opts=("-xf")
                    [[ "$verbose" == "true" ]] && tar_opts=("-xvf")
                    tar "${tar_opts[@]}" "$file" -C "$target_dir" || {
                        exit_code=$?
                        log_error "Fehler beim Extrahieren von $file (Code: $exit_code)"
                    }
                    ;;
                *.zip) 
                    unzip -l "$file" ;;
                *.7z) 
                    7z l "$file" ;;
                *) 
                    log_error "Nicht unterstütztes Archiv: $file"; 
                    exit_code=1 ;;
            esac
        done
        return $exit_code
    else
        # Extract mode
        if [[ ${#input_files[@]} -eq 0 ]]; then
            log_error "Keine Archive zum Extrahieren angegeben"
            return 1
        fi
        
        local exit_code=0
        for file in "${input_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                log_error "Archiv nicht gefunden: $file"
                exit_code=1
                continue
            fi
            
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
                    # Extrahiere in das gleiche Verzeichnis wie das Target
                    mkdir -p "$target_dir"
                    # Verzeichnis der Subdatei erstellen, falls benötigt
                    mkdir -p "$target_dir/subdir"
                    
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
                    unzip_opts=()
                    [[ "$verbose" == "true" ]] && unzip_opts+=("-v")
                    unzip "${unzip_opts[@]}" "$file" -d "$target_dir" || exit_code=$?
                    ;;
                *.7z) 
                    sz_opts=("x")
                    [[ "$verbose" == "true" ]] && sz_opts+=("-v")
                    sz_opts+=("$file" "-o$target_dir")
                    7z "${sz_opts[@]}" || exit_code=$?
                    ;;
                *) 
                    log_error "Nicht unterstütztes Archiv: $file"
                    exit_code=1
                    ;;
            esac
            
            if [[ $exit_code -eq 0 ]]; then
                log_success "Extrahiert: $file"
                if [[ "$delete_after" == "true" && -f "$file" ]]; then
                    rm "$file" && debug_info "Original gelöscht: $file"
                fi
            else
                log_error "Fehler beim Extrahieren von $file"
            fi
        done
    fi

    # Debugging deaktivieren
    $debug && set +x

    # Überprüfe auf notwendige Tools
    check_dependencies

    return $exit_code
}

# Vor der Kompression
check_space() {
    local required_space=0
    for item in "$@"; do
        if [[ -e "$item" ]]; then
            local size=$(du -s "$item" | awk '{print $1}')
            required_space=$((required_space + size))
        fi
    done
    
    # Kompressionsformat-Faktor berücksichtigen
    case "$compress_format" in
        tar.gz|zip) required_space=$((required_space / 2)) ;;
        tar.bz2|tar.xz) required_space=$((required_space / 3)) ;;
    esac
    
    local available_space=$(df -k "$target_dir" | tail -1 | awk '{print $4}')
    if [[ $required_space -gt $available_space ]]; then
        log_error "Nicht genügend Speicherplatz: Benötigt ca. ${required_space}KB, verfügbar: ${available_space}KB"
        return 1
    fi
    return 0
}

_pac_autocomplete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"         # Aktuelles Argument
    local prev="${COMP_WORDS[COMP_CWORD-1]}"     # Vorheriges Argument
    local opts="-c --compress -x --extract -v --verbose -t --target -d --delete -n --name -e --exclude -i --include -f --filter --debug -h --help -l --list -j --jobs -p --password"
    local formats="tar tar.gz tar.bz2 tar.xz tar.zst zip 7z"
    local supported_archives=()

    # Generiere unterstützte Archivdateien
    for pattern in "*.tar" "*.tar.gz" "*.tar.bz2" "*.tar.xz" "*.tar.zst" "*.zip" "*.7z"; do
        while IFS= read -r file; do
            [[ -n "$file" ]] && supported_archives+=("$file")
        done < <(compgen -G "$pattern" 2>/dev/null)
    done

    # Vorschläge basierend auf Kontext
    if [[ "${COMP_CWORD}" -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
        return
    fi

    case "$prev" in
        -x|--extract)
            if [[ ${#supported_archives[@]} -gt 0 ]]; then
                COMPREPLY=($(compgen -W "${supported_archives[*]}" -- "$cur"))
            else
                COMPREPLY=($(compgen -f -- "$cur"))
            fi
            return
            ;;
        -c|--compress)
            COMPREPLY=($(compgen -W "$formats" -- "$cur"))
            return
            ;;
        -t|--target)
            COMPREPLY=($(compgen -d -- "$cur"))
            return
            ;;
        -e|--exclude|-i|--include|-f|--filter)
            COMPREPLY=($(compgen -f -- "$cur"))
            return
            ;;
        -n|--name)
            COMPREPLY=("archive")
            return
            ;;
        -j|--jobs)
            COMPREPLY=($(compgen -W "1 2 3 4 5 6 7 8 9 10" -- "$cur"))
            return
            ;;
        -p|--password)
            COMPREPLY=()
            return
            ;;
        *)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "$opts" -- "$cur"))
            else
                COMPREPLY=()
            fi
            return
            ;;
    esac
}
complete -F _pac_autocomplete pac
