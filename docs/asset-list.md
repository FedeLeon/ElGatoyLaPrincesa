# Assets activos

Inventario de recursos que usa la demo actual. Las escenas y modelos se resuelven tanto desde scripts como mediante URI internos de GLTF; esos enlaces internos también cuentan como dependencias.

| Grupo | Ubicación | Uso actual |
| --- | --- | --- |
| Arte ilustrado del bosque | `assets/created/isometric/pixel_*.png` | Nimbo, bandido, árboles, helechos, rocas, santuario, puerta, escaleras, antorchas y piedras guía. |
| Princesa pintada | `assets/created/isometric/princess_painted_*.png` | Hojas 2D originales de caminata, arco, defensa, ataque y esquiva; pintura suave con alpha transparente. Generadas para el proyecto con la herramienta de imágenes integrada y retocadas para quitar residuos fuera de cada celda. |
| Animación 2D | `pixel_bandit_*`, `pixel_nimbo_walk_sheet.png` y `princess_painted_*.png` en la misma carpeta | Caminata, arco, defensa, ataque, esquiva, caída y caminata de Nimbo. |
| Suelo y terreno | `assets/created/materials/pixel_forest_floor.png`, `pixel_forest_path.png`, `ridge_stone_painterly.png` | Superficies de la cuadrícula y cordón montañoso. Los mapas fuente de materiales activos siguen en `assets/created/source/`. |
| Modelos de bosque | `assets/created/forest_models/` | Modelos y lotes del bosque; conservan referencias a la geometría Quaternius, mapas normales y materiales pintados. |
| Naturaleza Quaternius | `assets/quaternius/nature/` | Helechos y rocas originales usados por los lotes; incluye licencia y texturas dependientes. |
| Ruinas y utilería KayKit | `assets/kaykit/dungeon/`, `resources/`, `tools/` | Piezas del santuario, campamento y elementos del bosque. |
| Retrato de inventario | Celda frontal de `princess_painted_walk_sheet.png` | Retrato ilustrado que acompaña el inventario de la princesa. |
| UI | `assets/ui/` | Tema y fuente pixel, fondo del menú e iconos de inventario/equipo. |
| Audio | `assets/audio/`; generador `scripts/generate_game_audio.py` | Música, ambiente, pasos, combate, acertijo y UI. El audio original se regenera con Python 3, NumPy y FFmpeg. |
| Shaders | `assets/shaders/` | Cielo, agua, objetivo de casilla y tratamiento pixelado del terreno. |

Los packs de KayKit y Quaternius que siguen activos conservan sus archivos de licencia junto a sus recursos. Las texturas montañosas de Poly Haven conservan su licencia en `assets/polyhaven/`. Las imágenes de juego creadas para esta demo son originales; la princesa ahora usa acabado ilustrado pintado y el resto del mundo conserva su lectura pixel art, dentro de una fantasía natural sin copiar diseños o fotogramas de películas.

Las imágenes de `artifacts/visual-review/` son capturas de referencia, no contenido importado por el juego. `artifacts/.gdignore` evita que Godot las procese como texturas.
