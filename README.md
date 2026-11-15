# El gato y la Princesa

Demo de aventura 2.5D de cámara ortográfica en Godot 4. La princesa recorre un bosque de fantasía con movimiento por casillas y navegación por clic; Nimbo, un espíritu felino, acompaña la exploración. El objetivo es resolver el acertijo de las piedras guía y llegar al santuario.

## Ejecutar

1. Abrí `project.godot` con Godot 4.5 o posterior.
2. Ejecutá el proyecto con **F6/F5**, desde el botón de reproducir, o desde una terminal con `./scripts/run.sh`.

El lanzador acepta `GODOT_BIN=/ruta/a/Godot`; si no se indica, busca `.tools/godot`, `~/.local/bin/godot4` y luego `godot4` o `godot` en `PATH`. También acepta argumentos de Godot, por ejemplo `./scripts/run.sh --editor`.

## Controles

- **Clic izquierdo** en el suelo: caminar hacia la casilla indicada.
- **E**: interactuar con personajes, piedras guía y santuario.
- **F**: ataque con bastón; **Q**: defensa.
- **C**: sacar o guardar el arco; apuntá con el cursor y dispará con clic derecho.
- **I**: inventario; **Esc**: pausa; **R**: reiniciar. El desplazamiento se ordena con clic izquierdo; clic medio esquiva hacia el cursor.
- **Mando**: A interactuar, X bastón, Y arco, View pausa. El stick y los botones del mando no desplazan a la princesa.

## Proyecto

La dirección actual es pixel art hecho a mano en una vista 2.5D alineada a los ejes del movimiento. Las casillas solo organizan la navegación: el terreno no muestra una cuadrícula. Los modelos 3D y texturas de soporte se conservan cuando sirven a colisiones, anclajes de equipamiento o animación; el arte visible del elenco es pixel art. Los recursos y licencias activos se registran en [docs/asset-list.md](docs/asset-list.md).
