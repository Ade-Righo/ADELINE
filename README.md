# ADELINE
Adeline es un lanzador y gestor interactivo para Linux que simplifica el uso de Waydroid, automatizando diagnósticos, sockets y transferencias de archivos mediante un menú limpio y accesible.
Se proyecta como una herramienta de código abierto en constante evolución: robusta para los usuarios experimentados que buscan optimizar su tiempo, y lo suficientemente limpia y transparente para servir de guía a quienes están aprendiendo a dominar la terminal. Un reflejo de que la tecnología debe ser una extensión de nuestra creatividad, diseñada con propósito, respeto por los datos y hecha para durar.

El script comienza con la directiva inicial para Bash y verifica si se está ejecutando desde una interfaz gráfica sin una terminal activa; si es así, busca automáticamente emuladores como Konsole, Gnome-Terminal, Alacritty o Xterm para relanzarse a sí mismo en una ventana interactiva.

A continuación, define la ruta de instalación global en /usr/local/bin/R-Adeline-w. Si el script no se encuentra ejecutándose desde esa ubicación o el archivo aún no existe, copia el script actual a dicha ruta de sistema y le otorga permisos de ejecución mediante sudo para que pueda ser invocado desde cualquier terminal del sistema con facilidad.

Se configuran las variables de codificación internacional (LANG y LC_ALL a C.UTF-8) para garantizar que los caracteres especiales y los símbolos gráficos se rendericen correctamente sin fallos de codificación en el terminal.

Se definen los códigos de color ANSI de la paleta estética (verde, azul, cian, gris, rojo, magenta y amarillo) para estructurar la interfaz visual de la consola con un estilo moderno tipo ciberespacio.

El script detecta el idioma del sistema operativo mediante variables de entorno. Si comienza con inglés, configura todos los textos descriptivos, menús y mensajes de estado en inglés; de lo contrario, carga por defecto todo el diccionario de textos en español.

Se define la función de validación de privilegios de administrador verificar_sudo, la cual comprueba si el usuario tiene una sesión de sudo activa. Si no la tiene, muestra un aviso de error personalizado y cancela el flujo; si la tiene, mantiene la sesión de superusuario activa en segundo plano mediante un bucle silencioso para evitar pedir la contraseña repetidamente en cada acción.

La pantalla se limpia por completo y se dibuja el logotipo oficial de bienvenida de Adeline junto con la versión actual y la firma del autor.

Se ejecuta una pequeña animación con puntos suspensivos para simular una sincronización de núcleos de telemetría y dar una transición fluida antes de mostrar los datos del sistema.

El script analiza el rendimiento del equipo extrayendo los datos del procesador mediante los comandos top y lscpu, calculando el porcentaje de uso actual de la CPU, identificando el modelo exacto del procesador y generando una barra de progreso visual construida con bloques Unicode.

Se consulta el consumo de memoria RAM utilizando el comando free, calculando el total en gigabytes, el espacio utilizado y el porcentaje general, para luego representar el uso en tiempo real mediante otra barra gráfica porcentual.

Se consulta la tarjeta gráfica (GPU) instalada en el equipo utilizando el comando lspci para filtrar el controlador de video y mostrar su descripción comercial o genérica en pantalla.

Se evalúa el estado del contenedor de Waydroid consultando systemctl. Si el servicio está activo, verifica si la sesión de usuario de Waydroid y su interfaz gráfica se encuentran operativas o sin ventana visual; si el contenedor está detenido, activa un modo de diagnóstico que revisa los últimos registros de errores críticos en el journalctl del sistema para mostrar al usuario la anomalía exacta encontrada.

El script busca de manera inteligente la ruta donde Waydroid almacena los archivos multimedia del usuario (/media/0), probando múltiples directorios posibles en el sistema para adaptarse a distintas distribuciones. Si encuentra la ruta, muestra su ubicación y asegura permisos totales de acceso; si no existe, avisa que se generará automáticamente al realizar la primera transferencia.

Se dibuja en pantalla el menú interactivo principal que enumera las cinco acciones disponibles: forzar reinicio y limpieza de sockets, mover archivos entre la PC y Waydroid, acceder al control de energía de la PC, iniciar los servicios de Waydroid o salir del sistema, solicitando al usuario que ingrese un número del 1 al 5.

Si el usuario selecciona la opción 1, el script solicita permisos de administrador, detiene el contenedor de Waydroid, mata cualquier proceso huérfano relacionado, elimina los sockets de comunicación corruptos, recarga el módulo del kernel binder_linux y vuelve a iniciar tanto el contenedor como la sesión de Waydroid, comprobando mediante un bucle de intentos si el sistema respondió correctamente.

Si el usuario selecciona la opción 2, verifica la existencia de la ruta multimedia de Waydroid y desplaza un submenú interno para gestionar archivos en dos direcciones: enviar archivos o carpetas desde la PC hacia directorios específicos de Waydroid (Descargas, Documentos, Imágenes o la raíz), o extraer contenido desde Waydroid hacia el directorio personal del usuario en la PC mediante un sistema de búsqueda flexible.

Si el usuario selecciona la opción 3, despliega un submenú de control de energía que permite reiniciar la estación de trabajo, apagarla por completo o cancelar la operación de forma segura.

Si el usuario selecciona la opción 4, solicita permisos de administrador y ejecuta de forma secuencial el arranque del servicio del contenedor, la sesión de usuario y la interfaz visual de Waydroid en segundo plano.

Si el usuario selecciona la opción 5, limpia la pantalla, muestra una animación de salida y presenta un mensaje final de agradecimiento de código abierto dedicado a los usuarios de Linux y a su hija Adeline, finalizando la ejecución del script con éxito.

Si el usuario introduce una opción inválida en el menú principal, muestra un mensaje de error en rojo y finaliza el ciclo operativo.

Al terminar cualquiera de las acciones seleccionadas en el menú, el script se detiene y muestra un mensaje solicitando presionar la tecla Enter para salir de la ventana de la terminal de manera controlada.


#!/bin/bash

# ==============================================================================
#                        ADELINE v0.9.8 [ Fabos ]
# ==============================================================================

# 1. Asegurar que el script corra dentro de una ventana de terminal interactiva al hacer doble clic
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    if command -v konsole &>/dev/null; then
        exec konsole -e "$0" "$@"
    elif command -v gnome-terminal &>/dev/null; then
        exec gnome-terminal -- "$0" "$@"
    elif command -v alacritty &>/dev/null; then
        exec alacritty -e "$0" "$@"
    elif command -v xterm &>/dev/null; then
        exec xterm -e "$0" "$@"
    fi
fi

# 2. Definición del comando global ejecutable (/usr/local/bin/R-Adeline-w)
INSTALL_PATH="/usr/local/bin/R-Adeline-w"

if [ ! -f "$INSTALL_PATH" ] || [ "$0" != "$INSTALL_PATH" ]; then
    echo -e "\n[*] Configurando e instalando el comando global 'R-Adeline-w'..."
    sudo cp "$0" "$INSTALL_PATH" 2>/dev/null || cp "$0" "$INSTALL_PATH"
    sudo chmod +x "$INSTALL_PATH" 2>/dev/null || chmod +x "$INSTALL_PATH"
    echo -e "✨ ¡Instalación completada! Ahora puedes escribir 'sudo R-Adeline-w' en cualquier terminal.\n"
fi

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Paleta de colores Cyber-Aesthetic (Neón & Soft Cyan)
VERDE="\033[38;5;48m"
AZUL="\033[38;5;39m"
CIAN="\033[38;5;51m"
GRIS="\033[38;5;245m"
ROJO="\033[38;5;196m"
MAGENTA="\033[38;5;201m"
AMARILLO="\033[38;5;226m"
RESET="\033[0m"

SYS_LANG="${LANG:-$LC_ALL}"
if [[ "$SYS_LANG" =~ ^en ]]; then
    TXT_SYNC="[✦] Synchronizing telemetry cores"
    TXT_CPU_CORE="Core"
    TXT_CPU_LOAD="Load"
    TXT_RAM_USE="Usage"
    TXT_RAM_VOL="Volume"
    TXT_GPU_UNIT="Unit"
    TXT_WAY_ONLINE="● Online (Active)"
    TXT_WAY_UI_ON="● Powered On & Operational"
    TXT_WAY_UI_OFF="● Powered Off (No visual window)"
    TXT_WAY_OFF="○ Stopped"
    TXT_DETECTIVE="[Fabos Detective - Analyzing logs]"
    TXT_NO_ERRORS="No recent critical alerts."
    TXT_ANOMALY="Anomaly detected:"
    TXT_PATH="Path"
    TXT_PATH_GEN="Will auto-generate on transfer"
    TXT_MENU_TITLE="AVAILABLE ACTIONS"
    TXT_OPT_1="Forced restart / Socket cleanup"
    TXT_OPT_2="Move files (PC <-> Waydroid)"
    TXT_OPT_3="Power Control (Reboot/Poweroff)"
    TXT_OPT_4="Start Waydroid (Container & Session)"
    TXT_OPT_5="Exit"
    TXT_PROMPT=" ❯ Enter command [1-5]: "
    TXT_SUDO_ERR="If this is not your fish do not proceed to changes Rood"
    TXT_RESET_OK="✨ Waydroid has been successfully reset!"
    TXT_RESET_WARN="⚠ Notice: Container started, but session took time to respond."
    TXT_RESET_SUG="Suggestion: Run 'sudo waydroid init -f'"
    TXT_START_WAY="[*] Starting Waydroid service and session..."
    TXT_START_OK="✨ Waydroid started successfully!"
    TXT_FILE_MGR="Waydroid File Manager"
    TXT_SEND="Send file/folder from PC to Waydroid"
    TXT_PULL="Extract file/folder from Waydroid to PC"
    TXT_DIR_PROMPT="Select direction (1 or 2): "
    TXT_PC_PATH="Type or drag the exact path on your PC: "
    TXT_DESTS="Destinations in Waydroid:"
    TXT_DEST_1="Downloads"
    TXT_DEST_2="Documents"
    TXT_DEST_3="Pictures"
    TXT_DEST_4="Multimedia Root (/media/0)"
    TXT_CHOOSE_DEST="Choose destination [1-4]: "
    TXT_TRANSFERRING="[*] Transferring file/folder..."
    TXT_TRANS_OK="✨ Transfer completed!"
    TXT_ERR_PATH="✖ Error: The origin path is not valid."
    TXT_CURRENT_W="Current content in Waydroid (Media/0):"
    TXT_EMPTY_DIR="(Empty folder)"
    TXT_EXTRACT_PROMPT="Type the name of the file or folder to extract: "
    TXT_EXTRACT_OK="✨ Successfully extracted to your home directory (~/)!"
    TXT_ERR_NOTFOUND="✖ Error: Requested file not found."
    TXT_PWR_TITLE="Power Control"
    TXT_PWR_1="Reboot PC (reboot)"
    TXT_PWR_2="Power off PC (poweroff)"
    TXT_PWR_3="Cancel"
    TXT_PWR_CHOOSE="Select an option [1-3]: "
    TXT_REBOOTING="[*] Rebooting workstation..."
    TXT_POWEROFFING="[*] Powering off workstation..."
    TXT_CANCELLED="Operation cancelled."
    TXT_EXITING="[✦] Exiting system"
    TXT_ERR_CMD="Command or option not recognized."
else
    TXT_SYNC="[✦] Sincronizando núcleos de telemetría"
    TXT_CPU_CORE="Núcleo"
    TXT_CPU_LOAD="Carga"
    TXT_RAM_USE="Uso"
    TXT_RAM_VOL="Volumen"
    TXT_GPU_UNIT="Unidad"
    TXT_WAY_ONLINE="● En línea (Activo)"
    TXT_WAY_UI_ON="● Encendida y Operativa"
    TXT_WAY_UI_OFF="○ Apagada (Sin ventana visual)"
    TXT_WAY_OFF="○ Detenido"
    TXT_DETECTIVE="[Fabos Detective - Analizando registro]"
    TXT_NO_ERRORS="Sin alertas críticas recientes."
    TXT_ANOMALY="Anomalía detectada:"
    TXT_PATH="Path"
    TXT_PATH_GEN="Se auto-generará al transferir"
    TXT_MENU_TITLE="ACCIONES DISPONIBLES"
    TXT_OPT_1="Forzar reinicio / Limpieza sockets"
    TXT_OPT_2="Mover archivos (PC <-> Waydroid)"
    TXT_OPT_3="Control de Energía (Reiniciar/Apagar)"
    TXT_OPT_4="Iniciar Waydroid (Contenedor y Sesión)"
    TXT_OPT_5="Salir"
    TXT_PROMPT=" ❯ Ingrese comando [1-5]: "
    TXT_SUDO_ERR="Si este no es tu pece no procedas a cambios Rood"
    TXT_RESET_OK="✨ ¡Waydroid se ha reestablecido con éxito!"
    TXT_RESET_WARN="⚠ Aviso: El contenedor arrancó, pero la sesión tardó en responder."
    TXT_RESET_SUG="Sugerencia: Ejecuta 'sudo waydroid init -f'"
    TXT_START_WAY="[*] Iniciando servicio y sesión de Waydroid..."
    TXT_START_OK="✨ ¡Waydroid se ha iniciado correctamente!"
    TXT_FILE_MGR="Gestor de Archivos Waydroid"
    TXT_SEND="Enviar archivo/carpeta desde la PC hacia Waydroid"
    TXT_PULL="Extraer archivo/carpeta desde Waydroid hacia la PC"
    TXT_DIR_PROMPT="Selecciona dirección (1 o 2): "
    TXT_PC_PATH="Escribe o arrastra la ruta exacta en tu PC: "
    TXT_DESTS="Destinos en Waydroid:"
    TXT_DEST_1="Descargas (Download)"
    TXT_DEST_2="Documentos (Documents)"
    TXT_DEST_3="Imágenes (Pictures)"
    TXT_DEST_4="Raíz multimedia (/media/0)"
    TXT_CHOOSE_DEST="Elige destino [1-4]: "
    TXT_TRANSFERRING="[*] Transfiriendo archivo/carpeta..."
    TXT_TRANS_OK="✨ ¡Transferencia completada!"
    TXT_ERR_PATH="✖ Error: La ruta de origen no es válida."
    TXT_CURRENT_W="Contenido actual en Waydroid (Media/0):"
    TXT_EMPTY_DIR="(Carpeta vacía)"
    TXT_EXTRACT_PROMPT="Escribe el nombre del archivo o carpeta a extraer: "
    TXT_EXTRACT_OK="✨ ¡Extraído con éxito a tu directorio personal (~/)!"
    TXT_ERR_NOTFOUND="✖ Error: No se encontró el archivo solicitado."
    TXT_PWR_TITLE="Control de Energía"
    TXT_PWR_1="Reiniciar la PC (reboot)"
    TXT_PWR_2="Apagar la PC (poweroff)"
    TXT_PWR_3="Cancelar"
    TXT_PWR_CHOOSE="Selecciona una opción [1-3]: "
    TXT_REBOOTING="[*] Reiniciando estación de trabajo..."
    TXT_POWEROFFING="[*] Apagando estación de trabajo..."
    TXT_CANCELLED="Operation cancelled."
    TXT_EXITING="[✦] Saliendo del sistema"
    TXT_ERR_CMD="Command or option not recognized."
fi

verificar_sudo() {
    sudo -v 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${ROJO}$TXT_SUDO_ERR${RESET}"
        sudo -k
        return 1
    fi
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    return 0
}

clear

echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
echo -e "${AZUL}║${RESET}${CIAN}                 ADELINE                    ${RESET}${AZUL}║${RESET}"
echo -e "${AZUL}║${RESET}${GRIS}             v0.9.8 [ Fabos ]               ${RESET}${AZUL}║${RESET}"
echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}"

echo -ne "${CIAN}$TXT_SYNC${RESET}"
for i in 1 2 3; do
    echo -ne "${CIAN}.${RESET}"
    sleep 0.12
done
echo -e ""

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int(100 - $1)}')
CPU_NAME=$(lscpu | grep "Model name" | sed 's/Model name:[ \t]*//')

COMPRESED_CPU=$((CPU_USAGE / 5))
BARRA_CPU=""
i=0
while [ $i -lt 20 ]; do
    if [ $i -lt $COMPRESED_CPU ]; then
        BARRA_CPU="${BARRA_CPU}█"
    else
        BARRA_CPU="${BARRA_CPU}░"
    fi
    i=$((i + 1))
done

echo -e "\n${CIAN}┌── [ CPU ]${RESET}"
echo -e "${AZUL}│${RESET}  $TXT_CPU_CORE: ${GRIS}${CPU_NAME:-Procesador Genérico}${RESET}"
echo -e "${AZUL}│${RESET}  $TXT_CPU_LOAD:  [${VERDE}${BARRA_CPU}${RESET}] ${VERDE}${CPU_USAGE}%${RESET}"

RAM_INFO=$(free | awk 'NR==2{printf "%s,%s,%s", $2, $3, $3*100/$2}')
RAM_TOTAL_KB=$(echo $RAM_INFO | cut -d',' -f1)
RAM_USED_KB=$(echo $RAM_INFO | cut -d',' -f2)
RAM_PERCENT=$(echo $RAM_INFO | cut -d',' -f3 | awk '{print int($1)}')

RAM_TOTAL_GB=$(awk "BEGIN {print $RAM_TOTAL_KB / 1024 / 1024}")
RAM_USED_GB=$(awk "BEGIN {print $RAM_USED_KB / 1024 / 1024}")

COMPRESED_RAM=$((RAM_PERCENT / 5))
BARRA_RAM=""
i=0
while [ $i -lt 20 ]; do
    if [ $i -lt $COMPRESED_RAM ]; then
        BARRA_RAM="${BARRA_RAM}█"
    else
        BARRA_RAM="${BARRA_RAM}░"
    fi
    i=$((i + 1))
done

echo -e "${CIAN}┌── [ RAM ]${RESET}"
echo -e "${AZUL}│${RESET}  $TXT_RAM_USE:    [${VERDE}${BARRA_RAM}${RESET}] ${VERDE}${RAM_PERCENT}%${RESET}"
echo -e "${AZUL}│${RESET}  $TXT_RAM_VOL: ${GRIS}${RAM_USED_GB:0:4} GB / ${RAM_TOTAL_GB:0:4} GB${RESET}"

GPU_NAME=$(lspci | grep -i vga | cut -d ':' -f3 | sed 's/^[ \t]*//')
echo -e "${CIAN}┌── [ GPU ]${RESET}"
echo -e "${AZUL}│${RESET}  $TXT_GPU_UNIT: ${GRIS}${GPU_NAME:-Gráficos Integrados / Dedicados}${RESET}"
echo -e "${AZUL}│${RESET}  VRAM:   ${VERDE}Dinámica / Compartida${RESET}"

echo -e "\n${CIAN}┌── [ Waydroid Core Status ]${RESET}"
WAYDROID_CONTAINER=$(systemctl is-active waydroid-container 2>/dev/null)

if [ "$WAYDROID_CONTAINER" = "active" ]; then
    echo -e "${AZUL}│${RESET}  Contenedor: ${VERDE}$TXT_WAY_ONLINE${RESET}"
    if pgrep -f "waydroid" | grep -q "session"; then
        if pgrep -f "waydroid show" >/dev/null || pgrep -f "hwcomposer" >/dev/null || ip link show waydroid0 >/dev/null 2>&1; then
            echo -e "${AZUL}│${RESET}  Interfaz (UI): ${VERDE}$TXT_WAY_UI_ON${RESET}"
        else
            echo -e "${AZUL}│${RESET}  Interfaz (UI): ${ROJO}$TXT_WAY_UI_OFF${RESET}"
        fi
    else
        echo -e "${AZUL}│${RESET}  Interfaz (UI): ${ROJO}$TXT_WAY_UI_OFF${RESET}"
    fi
else
    echo -e "${AZUL}│${RESET}  Contenedor: ${ROJO}$TXT_WAY_OFF${RESET}"
    echo -e "${AZUL}│${RESET}"
    echo -e "${AZUL}│${RESET}  ${MAGENTA}$TXT_DETECTIVE${RESET}"
    ULTIMO_ERROR=$(sudo journalctl -u waydroid-container -n 5 --no-pager 2>/dev/null | grep -iE "error|fail|died|killed|binder" | tail -n 2)
    if [ -n "$ULTIMO_ERROR" ]; then
        echo -e "${AZUL}│${RESET}  ${ROJO}$TXT_ANOMALY${RESET}"
        echo -e "$ULTIMO_ERROR" | sed 's/^/    │ /'
    else
        echo -e "${AZUL}│${RESET}  ${GRIS}$TXT_NO_ERRORS${RESET}"
    fi
fi

echo -e "\n${CIAN}┌── [ Enlaces de Red / Storage ]${RESET}"
W_USER_DIR=""
POSIBLES_RUTAS=(
    "/var/lib/waydroid/data/media/0"
    "$HOME/.local/share/waydroid/data/media/0"
    "/home/$USER/.local/share/waydroid/data/media/0"
)

for ruta in "${POSIBLES_RUTAS[@]}"; do
    if sudo [ -d "$ruta" ] || [ -d "$ruta" ]; then
        W_USER_DIR="$ruta"
        break
    fi
done

[ -z "$W_USER_DIR" ] && W_USER_DIR="/var/lib/waydroid/data/media/0"

if sudo [ -d "$W_USER_DIR" ] || [ -d "$W_USER_DIR" ]; then
    echo -e "${AZUL}│${RESET}  $TXT_PATH: ${VERDE}$W_USER_DIR${RESET}"
    sudo chmod -R 777 "$W_USER_DIR" 2>/dev/null
else
    echo -e "${AZUL}│${RESET}  $TXT_PATH: ${GRIS}$TXT_PATH_GEN${RESET}"
fi

echo -e "\n${AZUL}┌────────────────────────────────────────────┐${RESET}"
echo -e "${AZUL}│${RESET}             ${CIAN}$TXT_MENU_TITLE${RESET}           ${AZUL}│${RESET}"
echo -e "${AZUL}├────────────────────────────────────────────┤${RESET}"
echo -e "  ${VERDE}[1]${RESET} $TXT_OPT_1"
echo -e "  ${VERDE}[2]${RESET} $TXT_OPT_2"
echo -e "  ${VERDE}[3]${RESET} $TXT_OPT_3"
echo -e "  ${VERDE}[4]${RESET} $TXT_OPT_4"
echo -e "  ${VERDE}[5]${RESET} $TXT_OPT_5"
echo -e "${AZUL}└────────────────────────────────────────────┘${RESET}"

echo -ne "$TXT_PROMPT"
read opcion

case "$opcion" in
    1)
        verificar_sudo || exit 1
        echo -e "\n${CIAN}[*] Ejecutando limpieza y reinicio forzado de sockets...${RESET}"
        sudo systemctl stop waydroid-container 2>/dev/null
        sudo pkill -9 -f waydroid 2>/dev/null
        sudo rm -f /run/waydroid.socket 2>/dev/null
        sudo modprobe binder_linux 2>/dev/null
        sudo systemctl start waydroid-container
        waydroid session start >/dev/null 2>&1 &
        
        INTENTOS=0
        CORRIENDO=0
        while [ $INTENTOS -lt 5 ]; do
            if pgrep -f "waydroid" | grep -q "session"; then
                CORRIENDO=1
                break
            fi
            sleep 2
            INTENTOS=$((INTENTOS + 1))
        done

        if [ $CORRIENDO -eq 1 ]; then
            echo -e "${VERDE}$TXT_RESET_OK${RESET}"
        else
            echo -e "${ROJO}$TXT_RESET_WARN${RESET}"
            echo -e "${CIAN}$TXT_RESET_SUG${RESET}"
        fi
        ;;
    2)
        if [ ! -d "$W_USER_DIR" ]; then
            verificar_sudo || exit 1
            sudo mkdir -p "$W_USER_DIR/Download" "$W_USER_DIR/Documents" "$W_USER_DIR/Pictures"
            sudo chmod -R 777 "$W_USER_DIR" 2>/dev/null
        fi

        echo -e "\n${AZUL}╭── [ $TXT_FILE_MGR ] ──╮${RESET}"
        echo -e "  1) $TXT_SEND"
        echo -e "  2) $TXT_PULL"
        echo -ne "  $TXT_DIR_PROMPT"
        read dir_tipo
        
        if [ "$dir_tipo" = "1" ]; then
            echo -ne "  $TXT_PC_PATH"
            read -e origen_pc
            origen_pc="${origen_pc%\'}"
            origen_pc="${origen_pc#\'}"
            origen_pc="${origen_pc%\"}"
            origen_pc="${origen_pc#\"}"

            if [ -e "$origen_pc" ]; then
                echo -e "  $TXT_DESTS"
                echo -e "    1) $TXT_DEST_1"
                echo -e "    2) $TXT_DEST_2"
                echo -e "    3) $TXT_DEST_3"
                echo -e "    4) $TXT_DEST_4"
                echo -ne "  $TXT_CHOOSE_DEST"
                read dest_op
                
                case "$dest_op" in
                    1) DESTINO="$W_USER_DIR/Download" ;;
                    2) DESTINO="$W_USER_DIR/Documents" ;;
                    3) DESTINO="$W_USER_DIR/Pictures" ;;
                    *) DESTINO="$W_USER_DIR" ;;
                esac
                
                verificar_sudo || exit 1
                sudo mkdir -p "$DESTINO"
                sudo chmod 777 "$DESTINO" 2>/dev/null
                echo -e "${CIAN}$TXT_TRANSFERRING${RESET}"
                sudo cp -r "$origen_pc" "$DESTINO/"
                sudo chmod -R 777 "$DESTINO" 2>/dev/null
                echo -e "${VERDE}$TXT_TRANS_OK${RESET}"
            else
                echo -e "${ROJO}$TXT_ERR_PATH${RESET}"
            fi
            
        elif [ "$dir_tipo" = "2" ]; then
            echo -e "\n  $TXT_CURRENT_W"
            verificar_sudo || exit 1
            sudo ls -F "$W_USER_DIR" 2>/dev/null || echo "  $TXT_EMPTY_DIR"
            echo ""
            echo -ne "  $TXT_EXTRACT_PROMPT"
            read -e origen_w
            
            if sudo [ -e "$W_USER_DIR/$origen_w" ]; then
                RUTA_FINAL="$W_USER_DIR/$origen_w"
            elif sudo [ -e "$W_USER_DIR/Download/$origen_w" ]; then
                RUTA_FINAL="$W_USER_DIR/Download/$origen_w"
            elif sudo [ -e "$W_USER_DIR/Documents/$origen_w" ]; then
                RUTA_FINAL="$W_USER_DIR/Documents/$origen_w"
            elif sudo [ -e "$W_USER_DIR/Pictures/$origen_w" ]; then
                RUTA_FINAL="$W_USER_DIR/Pictures/$origen_w"
            else
                FOUND_FILE=$(sudo find "$W_USER_DIR" -name "$origen_w" 2>/dev/null | head -n 1)
                [ -n "$FOUND_FILE" ] && RUTA_FINAL="$FOUND_FILE" || RUTA_FINAL=""
            fi
            
            if [ -n "$RUTA_FINAL" ] && sudo [ -e "$RUTA_FINAL" ]; then
                sudo cp -r "$RUTA_FINAL" "$HOME/"
                sudo chown -R $USER:$USER "$HOME/$(basename "$RUTA_FINAL")" 2>/dev/null
                echo -e "${VERDE}$TXT_EXTRACT_OK${RESET}"
            else
                echo -e "${ROJO}$TXT_ERR_NOTFOUND${RESET}"
            fi
        fi
        ;;
    3)
        echo -e "\n${AZUL}╭── [ $TXT_PWR_TITLE ] ──╮${RESET}"
        echo -e "  1) $TXT_PWR_1"
        echo -e "  2) $TXT_PWR_2"
        echo -e "  3) $TXT_PWR_3"
        echo -ne "  $TXT_PWR_CHOOSE"
        read energia_op
        
        case "$energia_op" in
            1)
                echo -e "${CIAN}$TXT_REBOOTING${RESET}"
                systemctl reboot
                ;;
            2)
                echo -e "${ROJO}$TXT_POWEROFFING${RESET}"
                systemctl poweroff
                ;;
            *)
                echo -e "${CIAN}$TXT_CANCELLED${RESET}"
                ;;
        esac
        ;;
    4)
        verificar_sudo || exit 1
        echo -e "\n${CIAN}$TXT_START_WAY${RESET}"
        sudo systemctl start waydroid-container
        waydroid session start >/dev/null 2>&1 &
        sleep 2
        waydroid show >/dev/null 2>&1 &
        echo -e "${VERDE}$TXT_START_OK${RESET}"
        ;;
    5)
        clear
        echo -ne "\n${CIAN}$TXT_EXITING${RESET}"
        c=1
        while [ $c -le 8 ]; do
            echo -ne "${CIAN}.${RESET}"
            sleep 0.08
            c=$((c + 1))
        done
        clear
        
        echo -e "\n"
        echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
        echo -e "${AZUL}║${RESET}${CIAN}                 ADELINE                    ${RESET}${AZUL}║${RESET}"
        echo -e "${AZUL}║${RESET}${GRIS}             v0.9.8 [ Fabos ]               ${RESET}${AZUL}║${RESET}"
        echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}"
        echo -e "\n"
        echo -e "${AZUL}  ────────────────────────────────────────────────────────────────────────${RESET}"
        echo -e "${GRIS}  Este programa es de código abierto y libre para los usuarios de Linux.${RESET}"
        echo -e "${GRIS}  Hecho para ayudarnos entre los que saben y los que están aprendiendo.${RESET}"
        echo -e "${GRIS}  Puedes cambiar versiones y títulos con total libertad, respetando solo${RESET}"
        echo -e "${GRIS}  el nombre ${VERDE}Adeline${RESET}${GRIS} en honor a mi hija. Disfruten y mejoren el código.${RESET}"
        echo -e "${MAGENTA}  Los héroes son humanos... o algo así, pero mejores.${RESET}"
        echo -e "${AZUL}  ────────────────────────────────────────────────────────────────────────${RESET}\n"
        
        exit 0
        ;;
    *)
        echo -e "${ROJO}$TXT_ERR_CMD${RESET}"
        ;;
esac


