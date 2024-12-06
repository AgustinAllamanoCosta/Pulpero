# Pulpero

### Nota importante de responsabilidad

**DESCARGO DE RESPONSABILIDAD**: Este software utiliza modelos de IA para generar análisis y sugerencias. El propietario y los contribuyentes del código no se hacen responsables por los resultados, sugerencias o análisis generados por el software. Todas las respuestas y sugerencias deben ser verificadas cuidadosamente por el usuario final, ya que son generadas por un modelo de IA y podrían contener errores o inexactitudes. El uso de este software es bajo su propia responsabilidad.

## ¿Qué tiene este repo?

Este repositorio contiene código para un plugin multi IDE y multiplataforma que analiza código y su funcionalidad. Está diseñado para ser nativo en Neovim, pero incluye adaptadores para IDEs como IntelliJ, WebStorm y VScode. El objetivo es ofrecer una experiencia similar a Copilot pero sin necesidad de conexión a internet ni exposición de tu código a terceros.

### ¿Por qué el nombre Pulpero?

Pulpero hace referencia a las Pulperías de la vieja Buenos Aires. Los pulperos eran los dueños de estos establecimientos que solían dar consejos a las personas que iban a tomar o pasar el rato en su local. Me pareció un nombre apropiado para una IA que ofrece consejos sobre código.

## ¿Cómo usarlo?

- En IDEs: Resalta el código que quieras analizar, haz click derecho y selecciona "analizar".
- En Neovim: Selecciona el código en modo visual y ejecuta el comando ExpFn.
- Con la API REST: Realiza un POST a http://localhost:8080/explain. El body debe contener el código a analizar y el query param 'lang' debe especificar el lenguaje.

### Requisitos

*PENDIENTE*

### Instalación local

Para la instalación local, ejecuta el script correspondiente a tu sistema operativo:

*MacOS*
```bash
chmod +x install.sh && ./install.sh
```

*Linux*
```bash
chmod +x install_linux.sh && ./install_linux.sh
```

*Windows*
```powershell
install.ps1
```

Estos scripts se encargan de:
1. Descargar y configurar Lua en tu sistema operativo
2. Instalar LuaRocks como gestor de paquetes
3. Instalar Milua, el miniframework usado para crear la API REST

Una vez instaladas las dependencias, ejecuta en la raíz del repositorio:

```bash
lua ./lua/pulpero/core/init.lua
```

Esto iniciará el servidor en http://localhost:8080/. Para verificar su funcionamiento, accede a la URL base, que debería responder con el mensaje "The server is running".

### Configuración para Lazy en Neovim

Existen dos formas de instalar el repositorio con Lazy:

1. Para desarrollo local (si deseas hacer modificaciones):
```lua
{ 'Pulpero', dir="~/ruta/al/repo/Pulpero", opts = {} },
```

2. Para instalación directa desde GitHub:
```lua
{ 'AgustinAllamanoCosta/Pulpero', opts = {} },
```

La segunda opción te mantendrá actualizado con la última versión del repositorio.

### Configuración para otros IDEs

*IntelliJ*: PENDIENTE
*VScode*: PENDIENTE
*WebStorm*: PENDIENTE

### API REST

La API actualmente ofrece dos endpoints básicos. Esta API está diseñada principalmente para pruebas y desarrollo, NO SE RECOMIENDA SU USO EN ENTORNOS PRODUCTIVOS ya que no implementa validaciones de seguridad.

#### Endpoints disponibles:

1. **Healthcheck**
   - URL: `http://localhost:8080/`
   - Método: GET
   - Respuesta: "The server is running"

2. **Análisis de código**
   - URL: `http://localhost:8080/explain`
   - Método: POST
   - Body: String con el código a analizar
   - Query params: `lang` (tipo de lenguaje del código)

### Imagen Docker

*PENDIENTE*

### Solución de problemas

El plugin genera logs en la carpeta `/tmp` del usuario:

- **pulpero_debug.log**: Registra los pasos del core durante el análisis, configuración, prompts y respuestas del modelo.
- **pulpero_setup.log**: Documenta los pasos de inicialización del plugin.
- **pulpero_command.log**: Muestra la información del motor del modelo (llama.cpp).
- **pulpero_error.log**: Registra errores inesperados.

Los logs se recrean en cada petición para mantener un tamaño controlado y facilitar el debug de la última ejecución.

## ¿Cómo funciona?

Pulpero se compone de tres partes principales:

1. **Core en Lua**: Diseñado principalmente para Neovim, se encarga de:
   - Descargar y configurar el modelo (actualmente usando TinyLlama-1.1B-Chat)
   - Configurar Llama.cpp como motor de ejecución
   - Gestionar los parámetros del modelo
   - Formatear prompts y procesar respuestas

2. **Motor del modelo**: Utiliza llama.cpp para la ejecución del modelo de IA.

3. **Adaptadores IDE**: Los IDEs distintos a Neovim utilizan una versión compilada del core en C.

La presentación de las respuestas puede variar según el adaptador o interfaz utilizada, pero siempre se mantiene la integridad de la información generada por el modelo.
