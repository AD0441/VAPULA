# VAPULA identity

Name: **VAPULA**. Descriptor: **Data & Statistical Laboratory**. Author: **Creado por Sebastián Pastén F.**

Iconographic reference: [Vapula seal, Mathers/Crowley, 1904](https://commons.wikimedia.org/wiki/File:60-Vapula_seal.png). The exact Commons page marks the source public domain (life+70 and pre-1931 US publication), inspected on 2026-10-29. The source raster is not redistributed.

The new vector preserves the central enclosure, its inward shoulders, upper double-lobed stem and lower cross termination. It removes the circular inscription, outer ring, irregular curls, text and small ornaments. The construction is symmetric and defined in a 100-unit coordinate system. It is original authored geometry, not a trace of the bitmap and not the METATRON cube. Original project artwork is MIT.

The application icon and seal variants use black `#0B0B0B`, white and neutral grays. Light/dark SVG/PNG symbols have transparent backgrounds. The application icon uses a dark rounded enclosure and white strokes; at 16–32 pixels strokes increase from 2.2 to 5 geometry units for optical legibility.

Run `swift script/make_brand.swift "$PWD"`. The script uses AppKit and iconutil from macOS, emits editable `docs/assets/brand/symbol-light.svg`, `symbol-dark.svg`, 1024 PNGs, 1600×800 cover and `Resources/Brand/AppIcon.icns`. The SwiftUI welcome/footer seal uses the same coordinate construction. No raster generator or AI asset dependency.

METATRON's geometry discipline, PAIMON/RAZIEL's documentation structure and native sidebar footer were inspected. Their source code, icons and colors were not copied. References: [METATRON](https://github.com/AD0441/METATRON), [PAIMON](https://github.com/AD0441/PAIMON), [RAZIEL](https://github.com/AD0441/RadioWorkbench).


## Portada pública

La portada principal es `docs/assets/promo/vapula-portada.png`. Sigue la referencia de METATRON aportada por el autor: fondo navy oscuro, tipografía marfil a la izquierda y sello propio a la derecha. El autor pidió profundidad y detalle, evitando una composición plana de texto sobre negro; la imagen utiliza un relieve contenido, luz discreta y conexiones geométricas. Es una ilustración promocional generada, no una captura ni una nueva geometría del icono. La portada negra sencilla que emite `make_brand.swift` se conserva como recurso anterior y no es la cabecera pública actual.

La fotografía generada del Mac permanece sin cambios en el apartado de ventajas y el material de detalle. Procedencia y prompts: [imágenes promocionales](assets/promo/README.md). El icono y las variantes SVG/PNG del sello siguen utilizando la geometría original reproducible.
