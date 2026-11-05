# Guía WSL — Puesta en marcha en Windows

La mayoría del equipo trabaja en **Windows usando WSL (Ubuntu)**. Esta guía
lleva desde cero hasta tener el entorno listo. En Arch/Linux nativo salta al
paso 5.

---

## 1. Instalar WSL2 + Ubuntu

En **PowerShell (como administrador)**:

```powershell
wsl --install -d Ubuntu
```

Reinicia Windows si te lo pide. Al abrir "Ubuntu" desde el menú inicio, te
pedirá crear usuario y contraseña (esto es *dentro* de Linux, no es la de
Windows).

- **Windows 11** (o Windows 10 actualizado): WSLg viene incluido → las apps
  gráficas (GTKWave) funcionan sin nada más.
- Actualiza WSL si es viejo: `wsl --update`.

## 2. Terminal

Usa **Windows Terminal** (viene con Windows 11; en 10 está en la Microsoft
Store). Desde ahí abres la pestaña "Ubuntu".

## 3. Clonar el repo DENTRO de WSL (importante)

**No** clonar en `C:\...` (va muy lento por el puente 9p). Clonar en el home
de Linux:

```bash
cd ~
git clone git@github.com:cuter177/Arquitectura_de_Computadoras.git
cd Arquitectura_de_Computadoras
```

### Git: primeras opciones

```bash
sudo apt update && sudo apt install -y git
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"
git config --global core.autocrlf input   # evita CRLF (rompe los scripts .sh)
```

> El repo ya trae `.gitattributes` que fuerza LF en scripts, .tex y .vhd;
> `core.autocrlf input` es la contraparte en tu lado.

### Claves SSH para GitHub (generadas en WSL)

```bash
ssh-keygen -t ed25519 -C "tu@email.com"
cat ~/.ssh/id_ed25519.pub      # copia esto
# Pégalo en GitHub → Settings → SSH and GPG keys → New SSH key
ssh -T git@github.com          # debe decir "Hi <usuario>!"
```

## 4. Instalar las herramientas del proyecto

```bash
cd ~/Arquitectura_de_Computadoras
bash scripts/instalar.sh
```

Eso instala (según `scripts/requerimientos.txt`):

- `ghdl` — simulador VHDL (VHDL-2008)
- `gtkwave` — visor de ondas
- `latexmk` + `xelatex` + `texlive-publishers` (la clase **llncs** de Springer)
- `git`, `make`

Verificación sin instalar:

```bash
bash scripts/instalar.sh --check
```

## 5. OpenCode dentro de WSL

OpenCode corre **dentro de WSL** (es Linux):

```bash
curl -fsSL https://opencode.ai/v2/install | bash
```

Después, **siempre desde la raíz del repo**:

```bash
cd ~/Arquitectura_de_Computadoras
opencode
```

Ver `docs/guia-opencode.md` para el uso diario.

## 6. GTKWave: el tema de la GUI

GTKWave es gráfico. Tres escenarios:

| Escenario | Qué hacer |
|---|---|
| **Windows 11 / WSLg** (recomendado) | Nada. `scripts/vhdl-wave archivo.vcd` abre la ventana directo. Si no abre: `wsl --update` y reinicia WSL. |
| **Windows 10 sin WSLg** | Instala un X server en Windows (VcXsrv o GWSL), arráncalo, y en Ubuntu: `export DISPLAY=:0` (añádelo a `~/.bashrc`). |
| **Alternativa sin GUI** | Copia el `.vcd` a Windows y ábrelo con GTKWave instalado en Windows. `scripts/vhdl-wave` te ofrece esto con `explorer.exe`. |

Comprobación rápida de GUI:

```bash
echo $DISPLAY            # vacío = sin GUI
ls /mnt/wslg 2>/dev/null # existe = WSLg activo
```

## 7. Compilar un reporte en WSL

```bash
cd reportes/datapath-1
../../scripts/latexbuild main.tex     # genera build/main.pdf
```

Para abrir el PDF desde WSL (opciones, descomenta la que prefieras en
`scripts/latexbuild`):

```bash
wslview build/main.pdf                            # vía wslu: sudo apt install wslu
explorer.exe "$(wslpath -w build/main.pdf)"       # visor PDF de Windows
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| "Permission denied" en un script | `bash scripts/<script>` en lugar de `./scripts/<script>`, o `chmod +x scripts/*` |
| Los scripts fallan raro / errores de síntaxis raros | Finales CRLF: `git config --global core.autocrlf input` y re-clona; `.gitattributes` se encarga del resto |
| `llncs.cls not found` | `sudo apt install texlive-publishers` (lo hace `scripts/instalar.sh`) |
| PDF en blanco + miles de `Missing character ... in font nullfont` | Faltan las fuentes Latin Modern: `sudo apt install texlive-fonts-recommended` |
| `ghdl: not found` | `bash scripts/instalar.sh` |
| Lento todo el rato | Estás en `/mnt/c/...`; clona en `~` |
| No abre GTKWave | Ver tabla de GUI del paso 6 |
| GitHub pide contraseña | Usa SSH (paso 3) o un Personal Access Token |
