#!/usr/bin/env python3
"""Recorta los márgenes negros de una captura de GTKWave.

Uso: recortar_png.py entrada.png salida.png

Detecta automáticamente el bounding box de píxeles no-negros (el contenido
del panel de ondas) y recorta a ese área con un pequeño margen. Solo admite
PNG 8-bit RGB sin entrelazar, que es lo que genera GTKWave.
"""

import struct
import sys
import zlib


def leer_png(ruta):
    with open(ruta, "rb") as f:
        datos = f.read()
    if datos[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("no es un PNG")
    pos = 8
    idat = b""
    ancho = alto = None
    while pos < len(datos):
        largo = struct.unpack(">I", datos[pos:pos + 4])[0]
        tipo = datos[pos + 4:pos + 8]
        cuerpo = datos[pos + 8:pos + 8 + largo]
        pos += 12 + largo
        if tipo == b"IHDR":
            ancho, alto, prof, color, _, _, entrel = struct.unpack(
                ">IIBBBBB", cuerpo)
            if (prof, color, entrel) != (8, 2, 0):
                raise SystemExit(
                    f"formato no soportado: bitdepth={prof} "
                    f"colortype={color} interlace={entrel}")
        elif tipo == b"IDAT":
            idat += cuerpo
        elif tipo == b"IEND":
            break
    bruto = zlib.decompress(idat)
    bpp = 3
    fila = 1 + ancho * bpp
    filas = []
    for y in range(alto):
        inicio = y * fila
        filtro = bruto[inicio]
        linea = bytearray(bruto[inicio + 1:inicio + 1 + ancho * bpp])
        anterior = filas[-1] if filas else bytes(ancho * bpp)
        if filtro == 0:
            pass
        elif filtro == 1:
            for i in range(bpp, len(linea)):
                linea[i] = (linea[i] + linea[i - bpp]) & 0xFF
        elif filtro == 2:
            for i in range(len(linea)):
                linea[i] = (linea[i] + anterior[i]) & 0xFF
        elif filtro == 3:
            for i in range(len(linea)):
                izq = linea[i - bpp] if i >= bpp else 0
                linea[i] = (linea[i] + ((izq + anterior[i]) >> 1)) & 0xFF
        elif filtro == 4:
            for i in range(len(linea)):
                a = linea[i - bpp] if i >= bpp else 0
                b = anterior[i]
                c = anterior[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pre = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                linea[i] = (linea[i] + pre) & 0xFF
        else:
            raise SystemExit(f"filtro PNG {filtro} no soportado")
        filas.append(bytes(linea))
    return ancho, alto, filas


def escribir_png(ruta, ancho, alto, filas):
    bruto = bytearray()
    for linea in filas:
        bruto.append(0)
        bruto += linea
    def chunk(tipo, cuerpo):
        c = struct.pack(">I", len(cuerpo)) + tipo + cuerpo
        return c + struct.pack(">I", zlib.crc32(tipo + cuerpo) & 0xFFFFFFFF)
    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(bytes(bruto), 9)))
        f.write(chunk(b"IEND", b""))


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    ancho, alto, filas = leer_png(sys.argv[1])
    # El contenido útil lo delimita la columna de nombres (x≈30..110):
    # solo hay píxeles oscuros (el texto) en las filas con señales; por
    # debajo el lienzo del panel queda en blanco. Los márgenes de la
    # ventana de GTKWave son negro puro.
    # El contenido útil lo delimita la columna de nombres (x≈34..100):
    # una fila "con texto" mezcla píxeles claros (fondo) y oscuros (letras).
    # Las bandas negras del marco de la ventana son totalmente oscuras y el
    # lienzo vacío del panel, totalmente claro; el separador vertical entre
    # nombres y ondas (x≈102..107) queda fuera del rango.
    col_min, col_max = 34, min(100, ancho - 1)

    def hay_texto(y):
        linea = filas[y]
        claros = oscuros = 0
        for x in range(col_min, col_max):
            i = x * 3
            if linea[i] < 128 and linea[i + 1] < 128 and linea[i + 2] < 128:
                oscuros += 1
            elif linea[i] > 200 and linea[i + 1] > 200 and linea[i + 2] > 200:
                claros += 1
        return oscuros >= 2 and claros >= 2

    filas_con_texto = [y for y in range(alto) if hay_texto(y)]
    if not filas_con_texto:
        raise SystemExit("no se detectó la columna de nombres")
    min_y, max_y = filas_con_texto[0], filas_con_texto[-1]
    # Bounding box horizontal dentro de esas filas.
    min_x, max_x = ancho, -1
    for y in range(min_y, max_y + 1):
        linea = filas[y]
        for x in range(ancho):
            i = x * 3
            if linea[i] > 30 or linea[i + 1] > 30 or linea[i + 2] > 30:
                if x < min_x:
                    min_x = x
                if x > max_x:
                    max_x = x
    pad = 2
    min_x = max(0, min_x - pad)
    min_y = max(0, min_y - pad)
    max_x = min(ancho - 1, max_x + pad)
    max_y = min(alto - 1, max_y + pad)
    nuevo_ancho = max_x - min_x + 1
    nuevo_alto = max_y - min_y + 1
    recortadas = [f[min_x * 3:(max_x + 1) * 3] for f in filas[min_y:max_y + 1]]
    escribir_png(sys.argv[2], nuevo_ancho, nuevo_alto, recortadas)
    print(f"recortado: {ancho}x{alto} -> {nuevo_ancho}x{nuevo_alto}")


if __name__ == "__main__":
    main()
