# Crate for Ryoku: plan de pulido antes del lanzamiento

Fecha: 2026-11-12. Estado: decisiones de diseño cerradas (fase 0); pendiente de tu revisión antes del plan de implementación.

## Objetivo

Que cada superficie de Ryoku hable el lenguaje de Crate antes de publicar nada
(AUR, Ryostore, PR a Ryoku). La referencia de acabado es lo que ya está bien:
**Ask (el prompt de AI) y Rashin**, y el admin de Crate.

Criterio de "terminado" por superficie:

- Paleta del tema activo (nada de bermellón `#e2342a`, papel cálido `#f3ede1`,
  `#16110b`, `#8f8770`) y sus tipografías (display Bricolage 800 donde hay
  títulos, mono en navegación, UI en el resto).
- Selección según el lenguaje decidido en la fase 0 (relleno cian o velo +
  borde o barra), foco en cian, captions en cian, hover en cian claro.
- Japonés solo a través de UiPreferences.
- Captura antes/después en el sandbox, revisada contigo.

## Cómo se trabaja

- Cambios en el fork de Ryoku (`thecrateapp/ryoku`, `feat/user-theme-role-overrides`
  o ramas hijas por área, para poder partir el PR upstream).
- Cambios de Crate for Ryoku en `thecrateapp/crate-for-ryoku`.
- Todo se prueba en el Hyprland anidado (sandbox) con capturas; a tu escritorio
  solo llega por paquetes locales, después de que lo veas.
- Cada cambio de estilo queda tras los interruptores del tema: sin `themeStyle`,
  Ryoku se ve exactamente como hoy (requisito para que upstream lo acepte).

## Fase 0. Decisiones de diseño (conversación)

| # | Decisión | Opciones | Afecta a |
|---|---|---|---|
| D1 | Selección en controles pequeños (pestañas, segmentos, chips) | **Decidido (c), mixto:** pestañas con texto cian y subrayado de 2 px (como la navegación del admin); segmentos y chips de opción con relleno cian (como los chips de Crate) | ui/Tabs, Seg, Chips, Multi; todo el Hub, QS Bar Settings, Stage, Kit, Ryostore |
| D2 | Tipografía de navegación | **Decidido (a):** JetBrains Mono en mayúsculas espaciadas, como el admin (token nuevo `navFont`, que el tema fija a la mono) | Tokens, raíles del Hub y las apps, QS Bar Settings, Kit, pestañas |
| D3 | Launcher | **Decidido: paleta de comandos** (maqueta v2 en .superpowers/brainstorm). Ver "Especificación del launcher" abajo | launcher hero y main, alt-tab, app Crate (caché de imágenes), proveedor de Crate |
| D4 | Botón primario | **Decidido (c), mixto:** relleno cian con texto oscuro para la acción que confirma o cambia algo (Install, Apply, Save, Play); contorno cian para la de navegación (Open, Browse) | ui/Btn y diálogos |
| D5 | Pestañas de Kit y botón de cerrar | **Decidido:** siguen D1 (subrayadas, como el resto de pestañas) | Kit |
| D6 | Pantalla de bloqueo | **Decidido:** piel de bloqueo (qylock) propia de Crate, incluida en Crate for Ryoku | lockscreen |
| D7 | Cursor | **Decidido:** se queda Bibata Modern Ice (blanco) | rice |

### Especificación del launcher (D3)

- Paleta de comandos centrada y compacta (como la del admin de Crate): campo con
  subrayado cian, pestañas ALL / APPS / FILES / CRATE / REC subrayadas (D1) en
  JetBrains Mono (D2), resultados por secciones con caption cian, fila activa en
  velo + barra cian de 2 px, pie con atajos (↵ open, ⇥ mode, ⌥↵ actions) y
  recuento.
- Búsqueda normal: primero APPS y FILES (y el resto de proveedores locales),
  después CRATE limitado a 1 artista, 1 álbum y 1 pista, en el orden de la app
  (Artista → Álbum → Pista), con la pista "cr ⇥ for more".
- `cr <búsqueda>`: directo a Crate (etiqueta CRATE en el campo, pestaña CRATE):
  ARTISTS (fotos redondas), ALBUMS en rejilla con portada grande, TRACKS (portada
  pequeña y duración). ↵ reproduce, ⌥↵ añade a la cola, ⇧↵ abre en Crate.
- Imágenes: la app Crate guarda portadas y fotos en una caché local
  (`$XDG_CACHE_HOME/crate/launcher-art/`) y el resultado de `search` lleva la ruta
  del archivo; nunca una URL (llevan el ticket de acceso).
- Crate en la búsqueda normal: el launcher de Ryoku tiene que consultar al
  proveedor de Crate en cada búsqueda (hoy solo con la palabra clave `cr`): un
  proveedor de scripts que pueda optar a resultados globales con sección y límite,
  o un proveedor propio de Crate.
- Acciones: `play_item` (↵), una orden nueva `queue_item` (⌥↵) y `show` con el
  elemento (⇧↵) en el socket de control de la app.

## Fase 1. Base (fork de Ryoku)

Arreglar la raíz para que la mayoría de superficies se corrijan solas.

1. **Componentes Ryoku.Ui** (`ryoku/ui`): `Tabs` (y que respete navCaps),
   `Seg`, `Chips`, `Multi`, `KeyboardMap` según D1; `Picker` y `AppPicker`
   (hover de fila sin relleno hueso); foco de `Btn` y `SettingRow` en
   `Tokens.focus`; `Btn` primario según D4; `Cell` (rgba cálido fijo);
   `Slid` con `Tokens.mark`. Tamaño M, alcance enorme.
2. **Token nuevo** `navFont` (D2): la familia de la navegación (raíles,
   pestañas, captions de sección); el estilo del tema lo fija a la mono.
   Documentado en docs/store.md junto al resto de `style`.
3. **Tipografía compartida**: `shell/services/Theme.qml` deja de fijar Fraunces y
   JetBrainsMono y lee `Tokens.display/displayWeight/mono` (calendario, popups de
   música, OSD, notificaciones).
4. **Puentes de paleta** para las superficies con paleta propia que ignoran el
   tema con nombre (leen solo colors.json y caen al bermellón):
   - overview (`modules/overview/Singletons/Theme,Scheme`);
   - launcher compartido (`modules/launcher/shared/Singletons/Theme,Scheme`):
     fallbacks, `threadBg`, `providerFind`, Fraunces;
   - menú del escritorio (`modules/desktop` Theme);
   - plugins de Kit (`plugins/kit/Singletons`);
   - el patrón: leer `shell.json themePalette` y los switches de `themeStyle`
     como hace Tokens, sin duplicar lógica.
5. **Títulos con peso display**: los `Font.Medium` fijos (Hub 3, Ryostore 7,
   sidebar 3, Welcome 5).

Entregable: capturas del Hub, QS Bar Settings y el overview antes/después.

## Fase 2. Lo que se ve cada día

| Superficie | Qué cambia | Tamaño |
|---|---|---|
| Barra QS (widgets y paneles, incluido el centro de notificaciones) | Su Theme (`barstyles/qsbar/Theme.qml`) lee los switches: captions con `Tokens.caption` (no `sumiHi`), foco y marcas con `Tokens.mark/focus` (no `seal`), mono = `Tokens.mono`; fuentes fijas en PacmanMarker y WorkspaceWidget | L |
| Dock | La app activa sin píldora hueso (DockItem, DockItemChrome, DockBand): marca cian o velo + borde; rótulos con navFont | M |
| Panel lateral / centro de control | SidebarButton, SidebarToggle, ConnectionTile, Mixer, LevelSlider, tarjetas Wi-Fi/Bluetooth: selección, foco y captions; títulos con peso display | M |
| Notificaciones (popups) | Caption de la app, fuentes de Tokens, acciones según D4 | S-M |
| OSD | Mono de Tokens, pista con la marca | S |
| Overview (Super+Tab) | Tras el puente de la fase 1: selección de espacio con `Tokens.mark` | M |
| **Launcher** | Rediseño según D3 (hero, main, alt-tab, pestañas de categoría con navCaps) | L |
| Portapapeles | Títulos de panel con navCaps, fuentes de Tokens (ya casi está) | S |
| Menú del escritorio (clic derecho) | Chips, filas y acciones rápidas según D1 | S-M |
| Diálogos polkit / llavero | Texto de botón fijo `#fdeee6` | S |
| Calendario y popups de música | Display de Tokens (tras la fase 1) | S |

Entregable: recorrido automático del sandbox por todas estas superficies.

## Fase 3. Hub y apps

| Área | Qué cambia | Tamaño |
|---|---|---|
| Cabecera de página (22 copias) | Regla y etiqueta con `Tokens.mark` y `Tokens.caption`; idealmente extraída a un componente | M |
| Barra superior del Hub | Botones UPDATES y FILES activos | S |
| Add-ons | Tarjetas de plugin/bundle/omarchy y la hoja de bundle, píldora RUNNING | S-M |
| Chips de opción sueltos | Controls, Animations, Profile, usuarios, ZoneEditor, NacreWidgetChip | S |
| Avisos y placas | confirmaciones de Add-ons y Dictation, avisos y ERROR de GPU, chips de error y kill switch de Connections | S-M |
| Progreso y gráficas | UpdateRun, barras de progreso | S |
| Selección de texto y hover | ~15 sitios con ink/bone; hover con `hoverInk` | S |
| Ryostore | ProviderTabs, foco de tarjetas, miniaturas, filas de componentes, etiqueta UPDATE, progreso de instalación, búsqueda, títulos | M |
| Ryoport | Tarjetas activas, GuardSwitch, gráficas y progreso | S |
| Ryoshot | Estados activos según D1 | S |
| Selector de Ryogami | Puente de su Theme a Tokens (paleta, fuentes, valores de estilo calculados de su paleta para que la previsualización siga funcionando) y restyle de ~15 componentes (pestañas, índice, búsqueda, botones, interruptor, campos) | M-L |
| Welcome | Títulos, tarjetas de barra, progreso de pasos | S |
| Editor de Stage | Contornos y tarjetas de escena, mapa de colores del editor copiado (Appearance.qml) | M |
| Kit | Pestañas principales (D5), teléfono, devtools, test de tecleo | S-M |
| Rashin y Ask | Referencia: no se tocan | - |

## Fase 4. Piezas de Crate for Ryoku

1. **Iconos con marca** (regla validada con la hoja de prueba):
   genéricas con Solar; marcas con Tabler (línea, MIT) si existe: Firefox,
   Chrome, Slack, Telegram, Steam, ChatGPT, Tidal, MongoDB; si no, Simple Icons
   (silueta, CC0): Claude, Thunderbird, Obsidian, Postman, JetBrains (+ PhpStorm y
   WebStorm por prefijo), ONLYOFFICE, mpv, Vim, Wine, NVIDIA, QEMU, CMake,
   Electron, LocalSend, CachyOS; si tampoco, el icono original recoloreado
   (Antigravity). Neovim: su marca es CC BY-SA, atribuirla o recolorear.
   Vendorizado con `brand_export.mjs` desde paquetes npm fijados, entrada
   `BRANDS` en app_glyphs.py, `brand_svg` en build_icons.py, NOTICE con MIT de
   Tabler, CC0 de Simple Icons y la línea de marcas registradas.
2. **Super+Alt+C abre Crate**: ya activo en tu escritorio (atajo propio de Ryoku);
   llevarlo en la rice para que viaje con Crate for Ryoku.
3. **Crate dentro del paquete**: `crate-desktop-bin` como dependencia del paquete
   AUR (no opcional); en la instalación desde release, `crate-for-ryoku install`
   descarga e instala la última release de Crate para el usuario si no está.
4. **Fastfetch**: lema propio de Crate en vez de "RYOKU · 力 · a hand-built
   CachyOS desktop".
5. **LS_COLORS** con la misma paleta que eza (ls, fd, tree, autocompletado).
6. **Cursor**: se queda Bibata Modern Ice (D7); nada que hacer.
7. **crate-mark**: estado sin Crate abierta, volumen (decidir en Crate: sincronizar
   con el del sistema o quitar el propio), revisión del panel contra la referencia.
8. **Pantalla de bloqueo** (D6): piel qylock propia de Crate: reloj en
   Bricolage 800, fecha en JetBrains Mono mayúsculas, fondo Groove, campo de
   contraseña con subrayado cian, lo que suena en Crate y estados de error en el
   rojo de Crate. Se instala con Crate for Ryoku y se elige en Ryoku Settings ›
   Lockscreen.
9. **Apps GTK y Qt**: comprobar con el tema Crate (Nautilus, diálogos de archivo,
   apps Qt) y corregir lo que haga falta en las plantillas.
10. **Imágenes**: vista previa de la rice en el Hub y capturas de Ryostore reales,
    sin portadas comerciales.

## Fase 5. Revisión visual y lanzamiento

1. Script de recorrido del sandbox que abre cada superficie y monta hojas de
   capturas; comparación lado a lado con el admin de Crate.
2. Ronda de detalles con esas hojas.
3. Lanzamiento, en este orden: AUR (`crate-for-ryoku`, `crate-desktop-bin`),
   PR a Ryostore (bundle + crate-mark), PRs a Ryoku upstream partidos por área
   (tema y Tokens; Ryoku.Ui; shell; Hub; apps).

## Orden y dependencias

Fase 0 (D1, D2, D3) → Fase 1 → Fases 2 y 3 en paralelo por áreas (2 primero, es
lo que se ve cada día) → Fase 4 (los iconos pueden ir en paralelo desde ya, no
dependen de Ryoku) → Fase 5.
