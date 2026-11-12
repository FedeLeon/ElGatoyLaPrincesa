# El gato y la Princesa

Demo de aventura 3D en Godot 4.5 o posterior. La princesa recorre un bosque de fantasía de unos 190 × 205 m, escucha a Nimbo, armoniza tres piedras guía y llega al santuario. Un bandido humanoide protege el sendero y presenta el arco, el bastón y la esquiva. La vegetación repetida se agrupa por celdas con `MultiMesh` para reducir nodos y llamadas de dibujo; los modelos y texturas principales se detallan en `docs/asset-list.md`.

## Ejecutar

1. Abrí `project.godot` con Godot 4.5 o posterior.
2. Ejecutá el proyecto con **F6/F5**, desde el botón de reproducir, o desde una terminal con `./scripts/run.sh`.

Al abrir el juego aparece el menú ilustrado. **Iniciar aventura** entra al bosque; **Opciones** permite cambiar volumen, sensibilidad del ratón y pantalla completa. Durante la partida, **Esc** abre la pausa con opciones y regreso al inicio.

El lanzador acepta `GODOT_BIN=/ruta/a/Godot`, y si no se indica busca `.tools/godot`, `~/.local/bin/godot4` y luego `godot4` o `godot` en `PATH`. En este equipo se preparó Godot 4.7.2 en `.tools/godot`; esa carpeta no forma parte del código versionado. Si hay una sesión Wayland, Godot 4.7 o posterior la selecciona automáticamente y conserva las decoraciones del escritorio. Las ejecuciones sin ventana y el driver elegido explícitamente se respetan; por ejemplo, `./scripts/run.sh --display-driver x11` o `./scripts/run.sh --editor`.

## Controles

- **WASD**: moverse.
- **Ratón**: orientar la cámara; clic vuelve a capturarlo.
- **E**: hablar, activar una piedra o examinar el santuario.
- **F**: ataque con bastón.
- **C**: sacar o guardar el arco; mantené **botón derecho** para apuntar y usá **clic izquierdo** para disparar.
- **Q**: defenderse con el bastón.
- **Espacio**: esquivar.
- **Esc**: pausa y liberar el ratón; **R** reinicia.
- **− / +**: ajustar la sensibilidad del ratón.
- **F3**: mostrar u ocultar FPS y tiempo aproximado por cuadro.
- **Mando**: stick izquierdo mover, stick derecho cámara, A interactuar o reiniciar, X bastón, Y arco, LT apuntar, RT disparar, LB defender, B esquivar, View pausa.

La princesa empieza con 8 flechas. Puede recoger otros carcajes junto al sendero, el campamento y las ruinas. Las flechas alcanzan al bandido a distancia; el apuntado acerca la cámara y muestra una mira.

Para reducir la resolución del mundo 3D en equipos lentos, ejecutá `./scripts/run.sh --low`. La interfaz conserva su resolución. También se puede ajustar con `GATO_3D_SCALE=0.6 ./scripts/run.sh` (entre 0.5 y 1.0).


## Mundo y dirección visual

El recorrido conecta el claro de entrada, un campamento lateral, ruinas cubiertas por el bosque, un arroyo con puente, tres piedras guía y el santuario. Los árboles, arbustos y rocas se instancian en lotes espaciales; el suelo y el camino usan pocas superficies grandes. Se desactivaron las sombras en la vegetación estática pequeña y se limitó su distancia de dibujo.

El bosque está rodeado de montañas con cascadas y límites físicos. Las rocas, los arbustos grandes y las estructuras tienen colisión; la vegetación pequeña se puede atravesar. El arroyo y las pozas son poco profundos y se pueden cruzar a pie: al caminar aparecen ondas y salpicaduras. El puente y la entrada al santuario tienen superficies transitables.

El suelo tiene lomas y depresiones suaves, con colisión ajustada al relieve. El sendero, el arroyo, el puente, los claros y la base de las estructuras conservan superficies niveladas para que el recorrido y las interacciones sigan siendo cómodos.

El claro de entrada tiene árboles altos cuyas copas cubren el camino, árboles de mayor porte, helechos, sendero texturado y un cielo con sol y nubes. Algunos árboles proyectan sombras y se limita la distancia de dibujado.

La princesa combina un modelo humano articulado, atuendo de exploradora, cabello y diadema de hojas; lleva el bastón en la mano y usa animaciones de reposo, carrera, ataque y esquiva. Los hongos y las mariposas animadas son geometría original agrupada en lotes.

La dirección busca fantasía natural original, con tonos verdes y tierra, bruma, luz cálida y siluetas legibles. Los modelos de Quaternius combinan geometría más detallada con formas estilizadas; los elementos narrativos y algunas ruinas aún son provisionales. Los packs, licencias y rutas usadas están documentados en [docs/asset-list.md](docs/asset-list.md).
