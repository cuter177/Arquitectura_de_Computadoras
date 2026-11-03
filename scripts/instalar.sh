#!/usr/bin/env bash
# ============================================================
# scripts/instalar.sh
# Instala (o verifica) todas las herramientas del proyecto:
#   GHDL, GTKWave, TeX Live con la clase llncs de Springer, etc.
#
# Compatible con: Ubuntu/Debian (incluido WSL), Arch, Fedora,
#                  macOS. En Windows nativo instruye para usar WSL.
#
# Uso:
#   bash scripts/instalar.sh            # instala lo que falte
#   bash scripts/instalar.sh --check    # solo verifica, no instala
#
# Basado en scripts/requerimientos.txt
# ============================================================
set -euo pipefail

SOLO_CHECK=0
[[ "${1:-}" == "--check" ]] && SOLO_CHECK=1

ROJO="\e[31m"; VERDE="\e[32m"; AMARILLO="\e[33m"; AZUL="\e[34m"; RESET="\e[0m"
ok()   { echo -e "  ${VERDE}[OK]${RESET}   $1"; }
falta(){ echo -e "  ${ROJO}[FALTA]${RESET} $1"; }
aviso(){ echo -e "  ${AMARILLO}[AVISO]${RESET} $1"; }
info() { echo -e "  ${AZUL}[INFO]${RESET} $1"; }

FALLOS=0

# ------------------------------------------------------------
# 1. Detectar entorno
# ------------------------------------------------------------
ES_WSL=0
if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    ES_WSL=1
fi

SISTEMA="desconocido"
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    SISTEMA="${ID:-desconocido}"
elif [[ "$(uname)" == "Darwin" ]]; then
    SISTEMA="macos"
fi

echo "============================================================"
echo " Instalación de herramientas — Arquitectura de Computadoras"
echo "============================================================"
if [[ $ES_WSL -eq 1 ]]; then
    echo -e " Entorno detectado: ${AZUL}WSL${RESET} (${WSL_DISTRO_NAME:-desconocido})"
else
    echo " Entorno detectado: $SISTEMA"
fi
echo ""

# Avisos específicos de WSL
if [[ $ES_WSL -eq 1 ]]; then
    # ¿Estamos dentro del filesystem de WSL y no en /mnt/c?
    if pwd -P | grep -qiE '^/mnt/[a-z]/'; then
        aviso "Estás en /mnt/c/... (filesystem de Windows). Es MUY lento con WSL."
        aviso "Clona el repo dentro de WSL:  cd ~ && git clone <url>"
    fi
fi

# ------------------------------------------------------------
# 2. Instalar dependencias según gestor de paquetes
# ------------------------------------------------------------
INSTALAR_APT() {
    sudo apt-get update
    sudo apt-get install -y \
        ghdl \
        gtkwave \
        latexmk \
        texlive-xetex \
        texlive-publishers \
        texlive-latex-extra \
        texlive-bibtex-extra \
        git \
        make
}

INSTALAR_PACMAN() {
    # OJO: `ghdl` NO está en los repositorios oficiales de Arch (se retiró y
    # ahora vive en AUR), así que un `pacman -S ghdl` falla con
    # "no se ha encontrado el paquete: ghdl". Primero lo oficial y después
    # GHDL desde AUR (ver INSTALAR_GHDL_AUR).
    sudo pacman -S --needed --noconfirm \
        gtkwave \
        texlive-bin \
        texlive-binextra \
        texlive-publishers \
        texlive-latexextra \
        git \
        make
    INSTALAR_GHDL_AUR
}

# GHDL en Arch solo está en AUR (paquete `ghdl`, backend mcode, depende de
# gcc-ada y se compila desde fuente: tarda varios minutos).
INSTALAR_GHDL_AUR() {
    if command -v ghdl >/dev/null 2>&1; then
        ok "ghdl ya está instalado; no hace falta tocar AUR"
        return 0
    fi

    local helper=""
    local h
    for h in yay paru; do
        if command -v "$h" >/dev/null 2>&1; then
            helper="$h"
            break
        fi
    done

    if [[ -n "$helper" ]]; then
        echo "--- GHDL (AUR: paquete 'ghdl', backend mcode) con $helper ---"
        "$helper" -S --needed --noconfirm ghdl
        hash -r   # para que la verificación vea el ghdl recién instalado
        return 0
    fi

    aviso "GHDL no está en los repos oficiales de Arch: hay que instalarlo desde AUR."
    info "  Opción A (recomendada): instala un helper de AUR y repite este script:"
    info "    sudo pacman -S --needed base-devel git"
    info "    git clone https://aur.archlinux.org/yay.git /tmp/yay && (cd /tmp/yay && makepkg -si)"
    info "    bash scripts/instalar.sh"
    info "  Opción B (sin helper, compila a mano):"
    info "    sudo pacman -S --needed base-devel git"
    info "    git clone https://aur.archlinux.org/ghdl.git /tmp/ghdl && (cd /tmp/ghdl && makepkg -si)"
    info "  Detalle: https://aur.archlinux.org/packages/ghdl"
    return 1
}

INSTALAR_DNF() {
    sudo dnf install -y \
        ghdl \
        gtkwave \
        texlive-scheme-medium \
        git \
        make
}

INSTALAR_BREW() {
    brew install ghdl gtkwave git make
    echo ""
    aviso "macOS: instala MacTeX (grande, ~5 GB) o BasicTeX + paquetes:"
    info "  brew install --cask mactex-no-gui   # o mactex"
    info "  Si usas BasicTeX: tlmgr install latexmk xetex llncs publishers"
}

# Ejecuta una función de instalación sin abortar el script si falla: la
# verificación de abajo dirá exactamente qué falta. Sin esto, `set -e` mata
# el script en el primer paquete problemático y el usuario no ve el resumen.
intentar_instalar() {
    local descripcion="$1"; shift
    if ! "$@"; then
        aviso "La instalación de $descripcion falló o se canceló; continúo con la verificación."
    fi
}

if [[ $SOLO_CHECK -eq 0 ]]; then
    case "$SISTEMA" in
        ubuntu|debian|pop|linuxmint|raspbian)
            echo "--- Instalando paquetes (apt) ---"
            intentar_instalar "los paquetes de apt" INSTALAR_APT
            ;;
        arch|manjaro|endeavouros|artix)
            echo "--- Instalando paquetes (pacman) ---"
            intentar_instalar "los paquetes de pacman/AUR" INSTALAR_PACMAN
            ;;
        fedora)
            echo "--- Instalando paquetes (dnf) ---"
            intentar_instalar "los paquetes de dnf" INSTALAR_DNF
            ;;
        macos)
            echo "--- Instalando (Homebrew) ---"
            intentar_instalar "los paquetes de Homebrew" INSTALAR_BREW
            ;;
        *)
            if [[ $ES_WSL -eq 1 ]]; then
                # WSL con distro no reconocida: probamos apt por si acaso
                if command -v apt-get >/dev/null 2>&1; then
                    echo "--- WSL: usando apt ---"
                    intentar_instalar "los paquetes de apt" INSTALAR_APT
                else
                    falta "Distro WSL no reconocida. Instala manualmente (ver docs/guia-wsl.md)."
                    FALLOS=$((FALLOS+1))
                fi
            else
                echo ""
                echo -e " ${ROJO}Sistema operativo no soportado por este script.${RESET}"
                echo "         Instala manualmente según scripts/requerimientos.txt"
                echo "         - Ubuntu/Debian: apt install ghdl gtkwave latexmk texlive-xetex texlive-publishers ..."
                echo "         - Arch:          pacman -S gtkwave texlive-publishers texlive-latexextra ..."
                echo "                          y GHDL desde AUR (p. ej. yay -S ghdl)"
                echo "         - Windows:       usa WSL2 + Ubuntu (docs/guia-wsl.md)"
                exit 1
            fi
            ;;
    esac
    echo ""
fi

# ------------------------------------------------------------
# 3. Verificar cada herramienta de requerimientos.txt
# ------------------------------------------------------------
echo "--- Verificación de requerimientos ---"

# ghdl
if command -v ghdl >/dev/null 2>&1; then
    V=$(ghdl --version | head -1)
    ok "ghdl: $V"
    # Prueba de humo con VHDL-2008
    TMPD=$(mktemp -d)
    if (cd "$TMPD" && printf 'entity tb_ok is end;\narchitecture a of tb_ok is begin end;\n' > tb_ok.vhd \
        && ghdl -a --std=08 tb_ok.vhd >/dev/null 2>&1); then
        ok "ghdl compila VHDL-2008 (--std=08)"
    else
        falta "ghdl no pudo analizar un .vhd de prueba con --std=08"
        FALLOS=$((FALLOS+1))
    fi
    rm -rf "$TMPD"
else
    falta "ghdl (simulador VHDL)"
    case "$SISTEMA" in
        arch|manjaro|endeavouros|artix)
            info "  En Arch GHDL NO está en los repos oficiales: instálalo desde AUR."
            info "    yay -S ghdl     # o: paru -S ghdl"
            ;;
    esac
    FALLOS=$((FALLOS+1))
fi

# gtkwave (+ GUI en WSL)
if command -v gtkwave >/dev/null 2>&1; then
    ok "gtkwave: $(gtkwave --version 2>/dev/null | head -1)"
    if [[ $ES_WSL -eq 1 ]]; then
        if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || -d /mnt/wslg ]]; then
            ok "GUI disponible en WSL (WSLg): GTKWave abrirá con normalidad"
        else
            aviso "Sin GUI en WSL: GTKWave no podrá abrirse aquí."
            info "  Opción A (Windows 11): activa WSLg -> wsl --update / reinicia WSL"
            info "  Opción B: instala un X server (VcXsrv/GWSL) y export DISPLAY"
            info "  Opción C: copia el .vcd a Windows y ábrelo con GTKWave de Windows"
            info "  Detalles: docs/guia-wsl.md"
        fi
    fi
else
    falta "gtkwave (visor de ondas)"
    FALLOS=$((FALLOS+1))
fi

# latexmk / xelatex
if command -v latexmk >/dev/null 2>&1; then
    ok "latexmk: $(latexmk --version 2>/dev/null | head -1)"
else
    falta "latexmk"
    FALLOS=$((FALLOS+1))
fi
if command -v xelatex >/dev/null 2>&1; then
    ok "xelatex disponible"
else
    falta "xelatex (texlive-xetex)"
    FALLOS=$((FALLOS+1))
fi

# llncs.cls + splncs04.bst (Springer)
if command -v kpsewhich >/dev/null 2>&1; then
    if kpsewhich llncs.cls >/dev/null 2>&1; then
        ok "llncs.cls -> $(kpsewhich llncs.cls)"
    else
        falta "llncs.cls (paquete texlive-publishers)"
        FALLOS=$((FALLOS+1))
    fi
    if kpsewhich splncs04.bst >/dev/null 2>&1; then
        ok "splncs04.bst -> $(kpsewhich splncs04.bst)"
    else
        falta "splncs04.bst (paquete texlive-publishers)"
        FALLOS=$((FALLOS+1))
    fi
else
    falta "kpsewhich (TeX Live no instalado)"
    FALLOS=$((FALLOS+1))
fi

# git / make
command -v git  >/dev/null 2>&1 && ok "git:  $(git --version)"  || { falta "git";  FALLOS=$((FALLOS+1)); }
command -v make >/dev/null 2>&1 && ok "make: $(make --version | head -1)" || { falta "make"; FALLOS=$((FALLOS+1)); }

# OpenCode (no bloqueante: solo aviso)
if command -v opencode >/dev/null 2>&1; then
    ok "opencode instalado"
else
    aviso "opencode no encontrado. Instálalo con:"
    info "  curl -fsSL https://opencode.ai/v2/install | bash"
fi

# Consejos WSL
if [[ $ES_WSL -eq 1 ]]; then
    echo ""
    info "Consejos WSL:"
    info "  - Configura git para no romper finales de línea:"
    info "      git config --global core.autocrlf input"
    info "  - Abre OpenCode SIEMPRE desde la raíz del repo (docs/guia-wsl.md)"
fi

# ------------------------------------------------------------
# 4. Resultado
# ------------------------------------------------------------
echo ""
echo "============================================================"
if [[ $FALLOS -eq 0 ]]; then
    echo -e " ${VERDE}Todo listo. Puedes trabajar con reportes y VHDL.${RESET}"
    echo "============================================================"
    exit 0
else
    echo -e " ${ROJO}Faltan $FALLOS comprobaciones. Revisa los mensajes [FALTA].${RESET}"
    echo "============================================================"
    exit 1
fi
