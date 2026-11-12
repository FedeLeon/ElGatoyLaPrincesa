# Plan de desarrollo

## Experimento actual — zona ampliada con modelos CC0

- Hipótesis: una pista narrativa y un patrón de tres piedras orientan la exploración hasta el santuario.
- Caso jugable: recorrer el bosque ampliado, hablar con Nimbo, activar las piedras en el orden luna/agua/semilla, apartar o vencer al bandido y cruzar el umbral.
- Prueba: una persona nueva identifica objetivo, pista y respuesta a sus acciones durante la escena renderizada.
- Falla observable: no encuentra la interacción, repite acciones sin entender el patrón, o no puede alcanzar la entrada.
- Decisión: la ruta se amplía con arroyo, puente, campamento, ruinas y santuario; la vegetación repetida se agrupa con MultiMesh. Revisar legibilidad y escala con jugadores en una PC dedicada.
- El perímetro se cierra con montañas, cascadas y colisiones; se amplía la vegetación y se añaden colisiones para rocas, arbustos grandes y estructuras. El arroyo y las pozas permiten caminar y generan ondas y salpicaduras; el puente y la rampa del santuario son transitables.
- Validación automatizada local: límites en los cuatro lados y una esquina, colisiones de rocas y arbustos, cruce del agua con efectos, recuperación tras caída, puente y acceso al santuario después de resolver las piedras. Falta una partida completa con una persona y validar en otros equipos.
- La esquiva toma el vector de movimiento relativo a la cámara al pulsar, reproduce la animación Roll ajustada a la duración del desplazamiento y orienta a la princesa hacia esa trayectoria. Si no hay dirección ingresada, usa el último sentido de marcha.
- La cámara de seguimiento se acerca a la princesa: el brazo se reduce de 6,0 m a 4,2 m y conserva su retracción al encontrar obstáculos.
- Arco KayKit con animaciones de apuntado y disparo, mira central, acercamiento de cámara mientras se apunta, flechas físicas visuales con impacto por consulta de colisión, munición y tres carcajes interactivos. Teclado/ratón: C, RMB, clic izquierdo; mando: Y, LT, RT.
- Menú inicial ilustrado con acciones para iniciar, abrir opciones y salir; opciones compartidas con la pausa para volumen, sensibilidad del ratón y pantalla completa. La pausa permite continuar o volver al menú.
- El suelo usa una malla ondulada con colisión coincidente; el relieve aumenta alrededor del sendero y conserva nivelados el camino, el arroyo, el puente, los claros y el santuario. Los objetos de vegetación se apoyan sobre el terreno.
- Nimbo ahora tiene silueta felina cuadrúpeda, patas con ciclo de marcha, cola móvil, materiales emisivos y una luz ambiental suave; sus pasos siguen la altura del terreno.
- El enemigo usa el esqueleto y cuerpo humanoide detallado de Quaternius, con capucha, máscara, capa, correas de cuero y daga. Conserva animaciones, hitbox, vida y lógica de combate.

## Core

- Mantener como prioridad visual la fantasía natural de Studio Ghibli y *La princesa Mononoke*, con acabado ilustrado y diseños originales; ver `docs/game-brief.md`.
- Recorrido de aproximadamente 190 × 205 m con objetivo, acertijo, criatura y estado de victoria.
- Movimiento/cámara en tercera persona para teclado/ratón y mando.
- Diálogo breve con pistas del espíritu felino.
- Modelos importados para la princesa, el bandido, vegetación, ruinas, santuario y herramientas; licencias en `docs/asset-list.md`.
- Cámara independiente con colisión; pausa recuperable; esquiva direccional y defensa con bastón; piedras identificadas y bandido con aviso de ataque.

## Support

- Bruma, luz filtrada, copas altas con sombras, cielo con sol y nubes y materiales de suelo y sendero texturados.
- HUD con objetivo, salud, interacciones y controles.

## Wishlist

- Diseño definitivo de personajes y animaciones, terreno con relieve y materiales ilustrados, composición de zonas, audio, guardado y progresión.

## Evidencia

- Godot 4.5.2 importó el proyecto y ejecutó la escena ampliada sin errores de script.
- L2 `GRAPHICAL_RUNTIME`: escena renderizada a 1280×720; cámara, modelos, ruta, vegetación, meta y HUD visibles.
- Medición local en llvmpipe, 1280 × 720, Godot 4.5.2: la captura de 30 cuadros a 30 FPS forzados tardó 5 s; CPU 100.91 ms/cuadro, GPU 101.99 ms/cuadro. La toma previa de la escena original registró CPU 114.8 y GPU 165.33 ms/cuadro. Es una mejora en este renderizador por software, no equivale al rendimiento en una GPU de PC.
- L3 `INPUT_REPLAY`: movimiento y diálogo de Nimbo; aceptación lógica también comprobó la secuencia, apertura del portal, dos golpes, derrota, esquiva y victoria.
- Mouse en ejecución, mando físico, exportación y PC de destino: pendientes.
- Revisión posterior: pruebas automatizadas de pausa, animaciones, dirección del golpe, defensa, esquiva, símbolos, apertura y victoria; el recorrido físico cruzó el puente y comprobó el sello cerrado y abierto.
- La opción `--low` establece escala 3D 0.7 (comprobada en ejecución). La escena se observó a 1280×720 con Godot 4.5.2; el acabado sigue usando modelos low-poly provisionales. La captura local en llvmpipe continúa lenta; medir FPS, percentiles y calidad tanto normal como baja en la PC objetivo antes de afirmar que corre fluido.
- En esta PC se preparó Godot 4.7.2 en `.tools/godot`; el lanzador selecciona Wayland para una ejecución normal si está disponible, respeta drivers explícitos y conserva el modo headless. La sesión gráfica identificó la AMD Radeon RX 570.
- Perfil local en tiempo real a 1280×720, con movimiento automatizado durante tres segundos en cada zona: entrada 119,5 FPS promedio, arroyo 119,9, vigía 114,3 y santuario 117,0; el percentil 95 del tiempo de cuadro fue respectivamente 9,60, 9,03, 13,74 y 9,13 ms. El máximo observado fue 22,75 ms. Godot informó que el protocolo FIFO no estaba disponible, por lo que la sincronización de cuadros merece revisión. Esto es una muestra breve en esta PC, no una prueba completa del recorrido ni de otros equipos.
- El claro de entrada ahora tiene sendero continuo, vegetación agrupada y colinas visuales de fondo. La revisión gráfica confirmó la composición, que sigue siendo una base KayKit low-poly para evolucionar hacia el arte ilustrado del brief.
- La princesa usa un rostro propio sin la cabeza Ranger, cabello, diadema y falda sobre el esqueleto animado. Se añadieron hierba texturada, más árboles, hongos agrupados y mariposas animadas; la estética low-poly sigue siendo provisional.
- Con Godot 4.7.2, Wayland y Radeon RX 570 a 1280×720, las muestras de tres segundos en arroyo, vigía y santuario registraron 144,9 FPS promedio y percentiles 95 de 7,31 a 7,53 ms; la entrada registró 71,9 FPS de promedio y 10,73 ms en el percentil 95, con un cuadro de unos 1004 ms. Una repetición de la entrada registró 97,1 FPS y otro cuadro de 1003 ms. El retraso también se observó al detener las mariposas y con la ventana sin foco; su causa no está identificada. Son muestras breves, no una garantía de estabilidad a 60 FPS.
- Revisión visual posterior: se incorporaron árboles y follaje de Quaternius, texturas de suelo de Poly Haven, cielo procedural y un modelo humano articulado con atuendo, cabello y animaciones. Se observaron la escena, el personaje de frente y una secuencia de movimiento, ataque y esquiva. Las comprobaciones de modelo, puente y santuario pasaron.
- Con la Radeon RX 570 a 1280×720, una muestra de tres segundos por zona en esta versión registró 69,3 FPS promedio en la entrada, 75,9 en el arroyo, 113,6 junto al vigía y 120,0 en el santuario; los percentiles 95 fueron 16,89, 16,84, 16,30 y 8,78 ms respectivamente. Las muestras son breves y el protocolo FIFO de la sesión Wayland no estaba disponible; no garantizan 60 FPS sostenidos en todo el recorrido.
