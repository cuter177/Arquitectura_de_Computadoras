#!/usr/bin/env python3
"""Recorta el borde negro de la ventana de GTKWave y el espacio vacío
inferior de las capturas de ondas del reporte datapath-1.

GTKWave (v3.3.116) vuelca con /File/Grab_To_File la ventana completa,
incluido el marco negro del gestor en esta sesión WSLg. Este script:

  1. si se indica SUP > 0, descarta las SUP filas superiores (barra de
     título y barra de herramientas, no pertinentes en el reporte),
  2. recorta al rectángulo no negro (elimina el marco),
  3. recorta la altura al último renglón con actividad en el panel de
     ondas (elimina el espacio en blanco sobrante),
  4. deja un margen blanco uniforme.

Uso:  python3 reportes/datapath-1/capturas/recortar.py <png_entrada> [SUP]
Con GTKWave 3.3.116/WSLg, SUP=115 elimina cabecera y toolbar dejando la
regla temporal completa. El árbol SST vacío de la izquierda se detecta y
se elimina automáticamente (busca el primer separador vertical completo
por debajo de la mitad izquierda).
"""
import sys

from PIL import Image


def es_marco(c):
    return abs(c[0] - 205) < 12 and abs(c[1] - 199) < 12 and abs(c[2] - 194) < 12


def recortar(ruta, sup=0):
    im = Image.open(ruta).convert("RGB")
    ancho, alto = im.size
    if sup > 0:
        im = im.crop((0, sup, ancho, alto))
        alto = im.size[1]
    px = im.load()

    # 0) eliminar el árbol SST vacío: primer separador vertical completo
    #    (color del marco) en la mitad izquierda => principio del panel
    #    de nombres de señales
    corte = 0
    for x in range(int(alto * 0.10), ancho // 2):
        n = sum(1 for y in range(0, alto, 2) if es_marco(px[x, y]))
        if n > (alto // 2) * 0.9:
            corte = x + 1
            break
    if corte:
        im = im.crop((corte, 0, ancho, alto))
        ancho, alto = im.size
    px = im.load()

    def negro(c):
        return c[0] < 60 and c[1] < 60 and c[2] < 60

    # 1) bbox de píxeles no negros = contenido útil (quita el marco)
    minx, miny, maxx, maxy = ancho, alto, 0, 0
    for y in range(alto):
        for x in range(ancho):
            if not negro(px[x, y]):
                minx = min(minx, x)
                maxx = max(maxx, x)
                miny = min(miny, y)
                maxy = max(maxy, y)

    # 2) dentro del contenido, buscar el último renglón con onda activa
    #    en el panel derecho (x >= 200) para quitar el vacío inferior
    ancho_cont = maxx - minx + 1
    x0 = minx + int(ancho_cont * 0.4)
    def fila_con_onda(y):
        return sum(1 for x in range(x0, maxx + 1) if sum(px[x, y]) < 250) > 4

    ultimo = maxy
    for y in range(maxy, miny, -1):
        if fila_con_onda(y):
            ultimo = y
            break
    # 2b) excluir filas "activas" aisladas abajo (thrash de una sola columna):
    _, active = [], []
    for y in range(miny, ultimo + 1):
        if fila_con_onda(y):
            active.append(y)
    if active:
        # último grupo contiguo de filas activas (tolerancia 3 px)
        fin = active[-1]
        for y in range(ultimo, miny, -1):
            consec = [a for a in active if abs(a - y) <= 3]
            if len(consec) >= 4:
                fin = max(consec)
                break
        ultimo = fin

    # 3) recorte al contenido + margen blanco uniforme
    contenido = im.crop((minx, miny, maxx + 1, ultimo + 1))
    margen = 6
    cw = contenido.size[0] + 2 * margen
    ch = contenido.size[1] + 2 * margen
    salida = Image.new("RGB", (cw, ch), (255, 255, 255))
    salida.paste(contenido, (margen, margen))
    salida.save(ruta)
    print(f"{ruta}: {ancho}x{alto} -> {salida.size[0]}x{salida.size[1]}")


if __name__ == "__main__":
    if not 2 <= len(sys.argv) <= 3:
        sys.exit("uso: recortar.py <png_entrada> [filas_superior]")
    sup = int(sys.argv[2]) if len(sys.argv) == 3 else 0
    recortar(sys.argv[1], sup)
