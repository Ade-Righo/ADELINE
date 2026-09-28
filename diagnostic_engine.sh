#!/bin/bash

# ==============================================================================
# MOTOR DE DIAGNÓSTICO AUTÓNOMO - ADELINE v0.9.8
# Sistema de escaneo y reparación inteligente para Waydroid y PC
# ==============================================================================

source "$(dirname "$0")/Adeline.md" 2>/dev/null || true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. REGISTRO DE DIAGNÓSTICOS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DIAG_LOG="$HOME/.adeline_diagnostics.log"
ISSUES_DB="$HOME/.adeline_issues.db"

# Estructura de fallos detectados
declare -A ISSUES_DETECTED
declare -a REPAIR_QUEUE

registrar_diagnostico() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local nivel="$1"  # ERROR, WARNING, INFO
    local modulo="$2"
    local mensaje="$3"
    
    echo "[$timestamp] [$nivel] [$modulo] $mensaje" >> "$DIAG_LOG"
    
    if [[ "$nivel" == "ERROR" || "$nivel" == "WARNING" ]]; then
        echo "$timestamp|$nivel|$modulo|$mensaje" >> "$ISSUES_DB"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. DIAGNÓSTICOS DE SISTEMA OPERATIVO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

diagnosticar_kernel() {
    registrar_diagnostico "INFO" "KERNEL" "Escaneando módulos del kernel..."
    
    # Verificar si binder_linux está cargado
    if ! lsmod | grep -q "binder_linux"; then
        registrar_diagnostico "ERROR" "KERNEL" "Módulo binder_linux NO CARGADO"
        ISSUES_DETECTED["kernel_binder"]="ERROR"
        return 1
    fi
    
    # Verificar ashmem
    if ! lsmod | grep -q "ashmem_linux"; then
        registrar_diagnostico "WARNING" "KERNEL" "Módulo ashmem_linux NO CARGADO (opcional pero recomendado)"
        ISSUES_DETECTED["kernel_ashmem"]="WARNING"
    fi
    
    # Verificar logs del kernel
    local dmesg_errors=$(sudo dmesg 2>/dev/null | grep -iE "error|fail|waydroid" | tail -5)
    if [ -n "$dmesg_errors" ]; then
        registrar_diagnostico "WARNING" "KERNEL" "Errores en dmesg: $(echo "$dmesg_errors" | head -1)"
        ISSUES_DETECTED["kernel_errors"]="WARNING"
    fi
    
    registrar_diagnostico "INFO" "KERNEL" "Escaneo de kernel completado"
}

diagnosticar_dependencias() {
    registrar_diagnostico "INFO" "DEPENDENCIES" "Verificando dependencias críticas..."
    
    local deps_required=("waydroid" "adb" "systemctl" "lxc")
    
    for dep in "${deps_required[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            registrar_diagnostico "ERROR" "DEPENDENCIES" "Falta herramienta requerida: $dep"
            ISSUES_DETECTED["missing_dep_$dep"]="ERROR"
        fi
    done
    
    registrar_diagnostico "INFO" "DEPENDENCIES" "Verificación completada"
}

diagnosticar_permisos() {
    registrar_diagnostico "INFO" "PERMISSIONS" "Escaneando permisos del sistema..."
    
    # Verificar si el usuario puede usar sudo sin contraseña
    if ! sudo -n true 2>/dev/null; then
        registrar_diagnostico "ERROR" "PERMISSIONS" "Usuario no tiene sudo sin contraseña"
        ISSUES_DETECTED["sudo_password"]="ERROR"
    fi
    
    # Verificar grupo kvm
    if ! groups "$USER" | grep -q "kvm"; then
        registrar_diagnostico "WARNING" "PERMISSIONS" "Usuario no está en grupo 'kvm' (podría ralentizar Waydroid)"
        ISSUES_DETECTED["group_kvm"]="WARNING"
    fi
    
    # Verificar permisos de waydroid data
    if [ -d "/var/lib/waydroid" ]; then
        if [ ! -w "/var/lib/waydroid" ]; then
            registrar_diagnostico "WARNING" "PERMISSIONS" "Permisos limitados en /var/lib/waydroid"
            ISSUES_DETECTED["waydroid_perms"]="WARNING"
        fi
    fi
    
    registrar_diagnostico "INFO" "PERMISSIONS" "Escaneo de permisos completado"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. DIAGNÓSTICOS DE WAYDROID
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

diagnosticar_contenedor_waydroid() {
    registrar_diagnostico "INFO" "WAYDROID_CONTAINER" "Analizando estado del contenedor..."
    
    local container_status=$(systemctl is-active waydroid-container 2>/dev/null)
    
    case "$container_status" in
        "active")
            registrar_diagnostico "INFO" "WAYDROID_CONTAINER" "Contenedor ACTIVO"
            ;;
        "inactive")
            registrar_diagnostico "ERROR" "WAYDROID_CONTAINER" "Contenedor INACTIVO"
            ISSUES_DETECTED["container_inactive"]="ERROR"
            ;;
        *)
            registrar_diagnostico "ERROR" "WAYDROID_CONTAINER" "Estado desconocido: $container_status"
            ISSUES_DETECTED["container_unknown"]="ERROR"
            ;;
    esac
    
    # Verificar logs del contenedor
    local container_logs=$(sudo journalctl -u waydroid-container -n 20 --no-pager 2>/dev/null)
    
    if echo "$container_logs" | grep -qiE "error|fail|died|killed"; then
        registrar_diagnostico "ERROR" "WAYDROID_CONTAINER" "Fallos en logs del contenedor"
        ISSUES_DETECTED["container_logs_error"]="ERROR"
        echo "$container_logs" | grep -iE "error|fail|died|killed" | while read line; do
            registrar_diagnostico "ERROR" "WAYDROID_CONTAINER" "LOG: $line"
        done
    fi
}

diagnosticar_sesion_waydroid() {
    registrar_diagnostico "INFO" "WAYDROID_SESSION" "Analizando sesión de Waydroid..."
    
    if ! pgrep -f "waydroid.*session" > /dev/null; then
        registrar_diagnostico "ERROR" "WAYDROID_SESSION" "Sesión de Waydroid NO ESTÁ CORRIENDO"
        ISSUES_DETECTED["session_not_running"]="ERROR"
        return 1
    fi
    
    registrar_diagnostico "INFO" "WAYDROID_SESSION" "Sesión ACTIVA"
    
    # Verificar interfaz gráfica
    if ! pgrep -f "waydroid show" > /dev/null && ! pgrep -f "hwcomposer" > /dev/null; then
        registrar_diagnostico "WARNING" "WAYDROID_SESSION" "Interfaz gráfica NO visible (posible headless mode)"
        ISSUES_DETECTED["ui_not_visible"]="WARNING"
    fi
    
    # Verificar conexión de red
    if ! ip link show waydroid0 > /dev/null 2>&1; then
        registrar_diagnostico "WARNING" "WAYDROID_SESSION" "Interfaz de red waydroid0 no encontrada"
        ISSUES_DETECTED["network_interface"]="WARNING"
    fi
}

diagnosticar_almacenamiento_waydroid() {
    registrar_diagnostico "INFO" "WAYDROID_STORAGE" "Escaneando almacenamiento..."
    
    local posibles_rutas=(
        "/var/lib/waydroid/data/media/0"
        "$HOME/.local/share/waydroid/data/media/0"
        "/home/$USER/.local/share/waydroid/data/media/0"
    )
    
    for ruta in "${posibles_rutas[@]}"; do
        if sudo [ -d "$ruta" ] 2>/dev/null || [ -d "$ruta" ] 2>/dev/null; then
            registrar_diagnostico "INFO" "WAYDROID_STORAGE" "Almacenamiento encontrado: $ruta"
            
            # Verificar permisos
            if ! [ -w "$ruta" ]; then
                registrar_diagnostico "ERROR" "WAYDROID_STORAGE" "Permisos insuficientes en: $ruta"
                ISSUES_DETECTED["storage_perms_$ruta"]="ERROR"
            fi
            
            # Verificar espacio disponible
            local espacio_disponible=$(df "$ruta" 2>/dev/null | awk 'NR==2 {print $4}')
            if [ "$espacio_disponible" -lt 1048576 ]; then  # < 1GB
                registrar_diagnostico "WARNING" "WAYDROID_STORAGE" "Espacio bajo en: $ruta (< 1GB disponible)"
                ISSUES_DETECTED["storage_space_low"]="WARNING"
            fi
            
            break
        fi
    done
}

diagnosticar_sockets() {
    registrar_diagnostico "INFO" "SOCKETS" "Escaneando sockets de Waydroid..."
    
    # Verificar socket de Waydroid
    if [ -S "/run/waydroid.socket" ]; then
        registrar_diagnostico "INFO" "SOCKETS" "Socket /run/waydroid.socket PRESENTE"
    else
        registrar_diagnostico "WARNING" "SOCKETS" "Socket /run/waydroid.socket NO ENCONTRADO"
        ISSUES_DETECTED["socket_missing"]="WARNING"
    fi
    
    # Verificar sockets huérfanos (pueden causar deadlocks)
    local socket_count=$(sudo lsof -c waydroid 2>/dev/null | grep -c "socket" || echo 0)
    if [ "$socket_count" -gt 50 ]; then
        registrar_diagnostico "WARNING" "SOCKETS" "Demasiados sockets abiertos: $socket_count (posible memory leak)"
        ISSUES_DETECTED["socket_leak"]="WARNING"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. DIAGNÓSTICOS DE CONECTIVIDAD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

diagnosticar_red_android() {
    registrar_diagnostico "INFO" "ANDROID_NETWORK" "Verificando conectividad Android..."
    
    # ADB connectivity
    if ! command -v adb &>/dev/null; then
        registrar_diagnostico "ERROR" "ANDROID_NETWORK" "ADB no está instalado"
        ISSUES_DETECTED["adb_missing"]="ERROR"
        return 1
    fi
    
    local devices=$(adb devices 2>/dev/null | grep -c "device$" || echo 0)
    
    if [ "$devices" -eq 0 ]; then
        registrar_diagnostico "WARNING" "ANDROID_NETWORK" "No hay dispositivos ADB detectados"
        ISSUES_DETECTED["adb_no_devices"]="WARNING"
    else
        registrar_diagnostico "INFO" "ANDROID_NETWORK" "Dispositivos ADB detectados: $devices"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. RESUMEN DE DIAGNÓSTICOS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

mostrar_resumen_diagnosticos() {
    clear
    
    echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${AZUL}║${RESET}${CIAN}     ADELINE - REPORTE DE DIAGNÓSTICO    ${RESET}${AZUL}║${RESET}"
    echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}\n"
    
    local error_count=0
    local warning_count=0
    
    # Contar problemas
    for issue in "${!ISSUES_DETECTED[@]}"; do
        if [[ "${ISSUES_DETECTED[$issue]}" == "ERROR" ]]; then
            ((error_count++))
        elif [[ "${ISSUES_DETECTED[$issue]}" == "WARNING" ]]; then
            ((warning_count++))
        fi
    done
    
    echo -e "${CIAN}┌── [ ESTADO GENERAL ]${RESET}"
    echo -e "${AZUL}│${RESET}  Errores detectados:    ${ROJO}$error_count${RESET}"
    echo -e "${AZUL}│${RESET}  Advertencias:          ${AMARILLO}$warning_count${RESET}"
    echo -e "${AZUL}│${RESET}  Timestamp:             ${GRIS}$(date '+%Y-%m-%d %H:%M:%S')${RESET}\n"
    
    if [ $error_count -gt 0 ]; then
        echo -e "${CIAN}┌── [ ERRORES CRÍTICOS ]${RESET}"
        for issue in "${!ISSUES_DETECTED[@]}"; do
            if [[ "${ISSUES_DETECTED[$issue]}" == "ERROR" ]]; then
                echo -e "${AZUL}│${RESET}  ${ROJO}✖${RESET} $issue"
            fi
        done
        echo ""
    fi
    
    if [ $warning_count -gt 0 ]; then
        echo -e "${CIAN}┌── [ ADVERTENCIAS ]${RESET}"
        for issue in "${!ISSUES_DETECTED[@]}"; do
            if [[ "${ISSUES_DETECTED[$issue]}" == "WARNING" ]]; then
                echo -e "${AZUL}│${RESET}  ${AMARILLO}⚠${RESET}  $issue"
            fi
        done
        echo ""
    fi
    
    echo -e "${CIAN}┌── [ REPARACIONES DISPONIBLES ]${RESET}"
    echo -e "  ${VERDE}[1]${RESET} Reparar todos los errores detectados"
    echo -e "  ${VERDE}[2]${RESET} Reparar solo errores críticos"
    echo -e "  ${VERDE}[3]${RESET} Mostrar detalles de diagnóstico"
    echo -e "  ${VERDE}[4]${RESET} Volver al menú principal"
    echo -e "  ${VERDE}[5]${RESET} Salir"
    echo -ne "\n$TXT_PROMPT"
    
    read opcion_diag
    
    case "$opcion_diag" in
        1) reparar_sistema "todos" ;;
        2) reparar_sistema "criticos" ;;
        3) mostrar_detalles_diagnosticos ;;
        4) return 0 ;;
        5) exit 0 ;;
        *) echo -e "${ROJO}Opción no válida${RESET}" ;;
    esac
}

mostrar_detalles_diagnosticos() {
    echo -e "\n${CIAN}Detalles de diagnóstico:${RESET}\n"
    
    if [ -f "$DIAG_LOG" ]; then
        tail -30 "$DIAG_LOG" | sed 's/^/  /'
    else
        echo "  No hay registros de diagnóstico disponibles"
    fi
    
    echo -ne "\n${GRIS}Presiona [ENTER] para continuar...${RESET}"
    read
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6. REPARACIONES AUTÓNOMAS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

reparar_kernel_binder() {
    registrar_diagnostico "INFO" "REPAIR" "Intentando reparar módulo binder_linux..."
    echo -e "${CIAN}[*] Cargando módulo binder_linux...${RESET}"
    
    if sudo modprobe binder_linux; then
        registrar_diagnostico "INFO" "REPAIR" "✓ Módulo binder_linux cargado exitosamente"
        echo -e "${VERDE}✓ Módulo cargado${RESET}"
        return 0
    else
        registrar_diagnostico "ERROR" "REPAIR" "Falló al cargar binder_linux (¿kernel antiguo?)"
        echo -e "${ROJO}✖ Fallo al cargar binder_linux${RESET}"
        echo -e "${AMARILLO}Sugerencia: Actualiza el kernel o compila módulos personalizados${RESET}"
        return 1
    fi
}

reparar_contenedor() {
    registrar_diagnostico "INFO" "REPAIR" "Reiniciando contenedor de Waydroid..."
    echo -e "${CIAN}[*] Deteniendo contenedor...${RESET}"
    
    sudo systemctl stop waydroid-container 2>/dev/null
    sleep 2
    
    echo -e "${CIAN}[*] Limpiando procesos huérfanos...${RESET}"
    sudo pkill -9 -f waydroid 2>/dev/null
    sleep 1
    
    echo -e "${CIAN}[*] Limpiando sockets...${RESET}"
    sudo rm -f /run/waydroid.socket 2>/dev/null
    
    echo -e "${CIAN}[*] Iniciando contenedor...${RESET}"
    if sudo systemctl start waydroid-container; then
        registrar_diagnostico "INFO" "REPAIR" "✓ Contenedor reiniciado exitosamente"
        echo -e "${VERDE}✓ Contenedor activo${RESET}"
        sleep 2
        
        # Iniciar sesión
        echo -e "${CIAN}[*] Iniciando sesión...${RESET}"
        waydroid session start >/dev/null 2>&1 &
        sleep 3
        
        if pgrep -f "waydroid.*session" > /dev/null; then
            registrar_diagnostico "INFO" "REPAIR" "✓ Sesión iniciada correctamente"
            echo -e "${VERDE}✓ Sesión activa${RESET}"
            return 0
        else
            registrar_diagnostico "WARNING" "REPAIR" "Sesión tardó en responder"
            echo -e "${AMARILLO}⚠ Sesión tardó pero el contenedor está activo${RESET}"
            return 0
        fi
    else
        registrar_diagnostico "ERROR" "REPAIR" "Falló reinicio del contenedor"
        echo -e "${ROJO}✖ Fallo al reiniciar contenedor${RESET}"
        return 1
    fi
}

reparar_permisos() {
    registrar_diagnostico "INFO" "REPAIR" "Reparando permisos del sistema..."
    
    if [ -d "/var/lib/waydroid" ]; then
        echo -e "${CIAN}[*] Ajustando permisos de Waydroid...${RESET}"
        sudo chmod -R 755 /var/lib/waydroid 2>/dev/null
        echo -e "${VERDE}✓ Permisos ajustados${RESET}"
        registrar_diagnostico "INFO" "REPAIR" "✓ Permisos corregidos"
    fi
}

reparar_grupo_kvm() {
    registrar_diagnostico "INFO" "REPAIR" "Agregando usuario al grupo kvm..."
    
    if ! groups "$USER" | grep -q "kvm"; then
        echo -e "${CIAN}[*] Agregando a grupo kvm (requerirá logout)...${RESET}"
        if sudo usermod -aG kvm "$USER"; then
            registrar_diagnostico "INFO" "REPAIR" "✓ Usuario agregado a grupo kvm"
            echo -e "${VERDE}✓ Usuario agregado al grupo kvm${RESET}"
            echo -e "${AMARILLO}⚠ Debes cerrar sesión y volver a iniciar para que surta efecto${RESET}"
            return 0
        fi
    fi
    
    return 0
}

reparar_almacenamiento() {
    registrar_diagnostico "INFO" "REPAIR" "Reparando almacenamiento..."
    
    local posibles_rutas=(
        "/var/lib/waydroid/data/media/0"
        "$HOME/.local/share/waydroid/data/media/0"
    )
    
    for ruta in "${posibles_rutas[@]}"; do
        if sudo [ -d "$ruta" ] 2>/dev/null || [ -d "$ruta" ] 2>/dev/null; then
            echo -e "${CIAN}[*] Creando estructura de directorios...${RESET}"
            sudo mkdir -p "$ruta/Download" "$ruta/Documents" "$ruta/Pictures" 2>/dev/null
            
            echo -e "${CIAN}[*] Ajustando permisos...${RESET}"
            sudo chmod -R 777 "$ruta" 2>/dev/null
            
            registrar_diagnostico "INFO" "REPAIR" "✓ Almacenamiento reparado"
            echo -e "${VERDE}✓ Almacenamiento reparado${RESET}"
            break
        fi
    done
}

reparar_sistema() {
    local modo="$1"  # "todos" o "criticos"
    
    clear
    echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${AZUL}║${RESET}${CIAN}        INICIANDO REPARACIONES        ${RESET}${AZUL}║${RESET}"
    echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}\n"
    
    # Verificar sudo
    if ! sudo -n true 2>/dev/null; then
        echo -e "${ROJO}Se requieren permisos de administrador${RESET}"
        return 1
    fi
    
    local reparaciones_exitosas=0
    local reparaciones_fallidas=0
    
    # Reparar errores críticos
    if [[ -v ISSUES_DETECTED["kernel_binder"] ]]; then
        reparar_kernel_binder && ((reparaciones_exitosas++)) || ((reparaciones_fallidas++))
    fi
    
    if [[ -v ISSUES_DETECTED["container_inactive"] ]] || [[ -v ISSUES_DETECTED["session_not_running"] ]]; then
        reparar_contenedor && ((reparaciones_exitosas++)) || ((reparaciones_fallidas++))
    fi
    
    # Reparar advertencias si modo="todos"
    if [[ "$modo" == "todos" ]]; then
        if [[ -v ISSUES_DETECTED["storage_perms"* ]]; then
            reparar_almacenamiento && ((reparaciones_exitosas++)) || ((reparaciones_fallidas++))
        fi
        
        if [[ -v ISSUES_DETECTED["group_kvm"] ]]; then
            reparar_grupo_kvm && ((reparaciones_exitosas++)) || ((reparaciones_fallidas++))
        fi
        
        if [[ -v ISSUES_DETECTED["waydroid_perms"] ]]; then
            reparar_permisos && ((reparaciones_exitosas++)) || ((reparaciones_fallidas++))
        fi
    fi
    
    echo -e "\n${CIAN}┌── [ RESUMEN DE REPARACIONES ]${RESET}"
    echo -e "${AZUL}│${RESET}  Exitosas:  ${VERDE}$reparaciones_exitosas${RESET}"
    echo -e "${AZUL}│${RESET}  Fallidas:  ${ROJO}$reparaciones_fallidas${RESET}\n"
    
    registrar_diagnostico "INFO" "REPAIR" "Reparaciones completadas: $reparaciones_exitosas exitosas, $reparaciones_fallidas fallidas"
    
    echo -ne "${GRIS}Presiona [ENTER] para continuar...${RESET}"
    read
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7. FUNCIÓN PRINCIPAL DE DIAGNÓSTICO
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ejecutar_diagnostico_completo() {
    clear
    
    echo -e "${AZUL}╔════════════════════════════════════════════╗${RESET}"
    echo -e "${AZUL}║${RESET}${CIAN}    ESCANEANDO SISTEMA (ANÁLISIS COMPLETO)  ${RESET}${AZUL}║${RESET}"
    echo -e "${AZUL}╚════════════════════════════════════════════╝${RESET}\n"
    
    # Limpiar detección anterior
    ISSUES_DETECTED=()
    
    echo -e "${CIAN}Escaneando módulos del kernel...${RESET}"
    diagnosticar_kernel
    sleep 0.5
    
    echo -e "${CIAN}Verificando dependencias...${RESET}"
    diagnosticar_dependencias
    sleep 0.5
    
    echo -e "${CIAN}Analizando permisos...${RESET}"
    diagnosticar_permisos
    sleep 0.5
    
    echo -e "${CIAN}Inspeccionando contenedor Waydroid...${RESET}"
    diagnosticar_contenedor_waydroid
    sleep 0.5
    
    echo -e "${CIAN}Analizando sesión Waydroid...${RESET}"
    diagnosticar_sesion_waydroid
    sleep 0.5
    
    echo -e "${CIAN}Escaneando almacenamiento...${RESET}"
    diagnosticar_almacenamiento_waydroid
    sleep 0.5
    
    echo -e "${CIAN}Verificando sockets...${RESET}"
    diagnosticar_sockets
    sleep 0.5
    
    echo -e "${CIAN}Probando conectividad ADB...${RESET}"
    diagnosticar_red_android
    sleep 0.5
    
    sleep 1
    mostrar_resumen_diagnosticos
}

# Exportar funciones para uso desde otros scripts
export -f ejecutar_diagnostico_completo
export -f registrar_diagnostico
