# datapath-2 en la DE10-Standard

Envoltorio de placa de **datapath-2**: pone la unidad de control y el datapath
de 8 bits en la FPGA para ejecutar los tres experimentos de la unidad sin
simulador: sumatoria `S(n)`, factorial `n!` y multiplicación `A×B` por sumas
repetidas.

No sustituye al diseño: `src/` y `tb/` quedan intactos y siguen validándose con
`scripts/vhdl-sim`. Lo único que hace este directorio es cablear los módulos a
los periféricos de la placa.

```
fpga/
  top_placa.vhd        envoltorio (FSM de captura + control + datapath + displays)
  tb_top_placa.vhd     autochequeo del envoltorio (simulación)
  top_placa.qpf        proyecto Quartus (doble clic para abrir)
  top_placa.qsf        dispositivo, fuentes y los 67 pines
  top_placa.sdc        restricciones de tiempo (CLOCK_50 = 20 ns)
  output_files/        .sof generado (ignorado por git)
```

Qué hay dentro de la FPGA:

```
 SW[9:8] ─────────────► modo (00 suma, 01 factorial, 10 multiplicación)
 SW[7:0] ─────────────► operando n / A / B

 KEY0 ─► pulsador ─► captura / ejecuta
 KEY3 ─────────────► reset

              ┌────────────────────┐
              │ FSM del envoltorio │  LISTO -> ESPERA_B -> EJECUTANDO -> FIN
              └─────────┬──────────┘
                        │ modo_reg, a_reg, b_reg, rst_dp
              ┌─────────▼──────────┐
              │ control + datapath │  8 bits, banco de 8 registros
              └─────────┬──────────┘
                        │ resultado_reg, cero_reg
              ┌─────────▼──────────┐
              │ 6 × hex7seg + LEDR │
              └────────────────────┘
```

---

# Guía de uso — día de la prueba

La placa no tiene teclado ni pantalla: la conversación son **10 interruptores,
4 botones, 10 LEDs y 6 displays**.

## 1. Qué es cada pin

| Pin | Tipo | Para qué sirve |
|---|---|---|
| `SW[9:8]` | entrada | **modo**: `00` suma, `01` factorial, `10` multiplicación; `11` no se usa |
| `SW[7:0]` | entrada | **operando**: `n` en suma/factorial, `A` o `B` en multiplicación |
| `KEY0` | entrada | ejecutar / capturar. En multiplicación: 1.ª pulsación captura `A`, 2.ª captura `B` |
| `KEY3` | entrada | reset general |
| `KEY1`, `KEY2` | entrada | sin uso |
| `HEX5:HEX4` | salida | operando `A` / `n` en hexadecimal (8 bits) |
| `HEX3:HEX2` | salida | operando `B` en hexadecimal (8 bits); `00` en suma/factorial |
| `HEX1:HEX0` | salida | **resultado** en hexadecimal (8 bits) |
| `LEDR[1:0]` | salida | modo: `00` suma, `01` factorial, `10` multiplicación |
| `LEDR[3:2]` | salida | estado: `00` listo, `01` esperando `B`, `10` ejecutando, `11` fin |
| `LEDR[4]` | salida | `cero` del resultado (encendido si el resultado es 0) |
| `LEDR[5]` | salida | resultado válido (encendido en `FIN`) |
| `LEDR[6]` | salida | ocupado (encendido mientras ejecuta) |
| `LEDR[7]` | salida | esperando `B` (encendido en `ESPERA_B`) |
| `LEDR[8]` | salida | modo inválido (`SW[9:8] = 11` en `LISTO`/`FIN`) |
| `LEDR[9]` | salida | siempre apagado |

Los `KEY` están activos a nivel bajo (pulsar = 0), pero lo resuelve el
envoltorio: tú solo pulsas.

## 2. El bucle de interacción

```
 ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
 │ 1. Pon modo y   │   │ 2. Pulsa KEY0   │   │ 3. Lee LEDR y   │   │ 4. Repite o     │
 │    operando en  │──►│    y suelta     │──►│    HEX          │──►│    cambia de    │
 │    SW           │   │                 │   │                 │   │    modo         │
 └─────────────────┘   └─────────────────┘   └─────────────────┘   └─────────────────┘
```

> El operando se captura **en el instante en que pulsas `KEY0`**. Si mueves los
> switches después, el resultado anterior se queda hasta la próxima ejecución.

## 3. Escribir el operando con los switches

Cada switch de `SW[7:0]` vale un peso binario; los que uses, en **ON** (arriba),
los demás abajo:

| Switch | `SW0` | `SW1` | `SW2` | `SW3` | `SW4` | `SW5` | `SW6` | `SW7` |
|---|---|---|---|---|---|---|---|---|
| Vale | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 |

El modo se elige con `SW[9:8]`:

| Modo | `SW9` | `SW8` |
|---|---|---|
| Suma (`00`) | abajo | abajo |
| Factorial (`01`) | abajo | arriba |
| Multiplicación (`10`) | arriba | abajo |
| Inválido (`11`) | arriba | arriba |

Mientras estás en `LISTO`, `HEX5:HEX4` muestra **en vivo** el valor de
`SW[7:0]`, para que compruebes el operando antes de pulsar.

## 4. Guion paso a paso

| Paso | Tú haces | La placa muestra | Qué significa |
|---|---|---|---|
| 1 | Enciendes y pulsas `KEY3` | `HEX5:0` = `00 00 00`, `LEDR[3:2]` = `00` | todo reiniciado, listo |
| 2 | Modo `00`, `SW[7:0]` = `05` (`SW0`+`SW2`), `KEY0` | `HEX5:4`=`0005`, `HEX3:2`=`0000`, `HEX1:0`=`000F`; `LEDR[3:2]`=`11`, `LEDR5` encendido | `S(5) = 15` |
| 3 | `SW[7:0]` = `03`, `KEY0` | `HEX1:0`=`0006` | `S(3) = 6` |
| 4 | Modo `01`, `SW[7:0]` = `05`, `KEY0` | `HEX5:4`=`0005`, `HEX1:0`=`0078`; `LEDR[1:0]`=`01` | `5! = 120` |
| 5 | `SW[7:0]` = `03`, `KEY0` | `HEX1:0`=`0006` | `3! = 6` |
| 6 | Modo `10`, `SW[7:0]` = `04`, `KEY0` | `LEDR[3:2]`=`01`, `LEDR7` encendido; `HEX5:4`=`0004` | `A = 4` capturada; espera `B` |
| 7 | `SW[7:0]` = `03`, `KEY0` | `HEX5:4`=`0004`, `HEX3:2`=`0003`, `HEX1:0`=`000C`; `LEDR[3:2]`=`11` | `4×3 = 12` |
| 8 | `SW[7:0]` = `0F`, `KEY0`; `SW[7:0]` = `0F`, `KEY0` | `HEX1:0`=`00E1` | `15×15 = 225` |
| 9 | `SW[7:0]` = `07`, `KEY0`; `SW[7:0]` = `00`, `KEY0` | `HEX1:0`=`0000`; `LEDR4` encendido | `7×0 = 0`; el flag `cero` se activa |
| 10 | `KEY3` | Vuelve a `00 00 00` y `LEDR[3:2]`=`00` | reset |

**En multiplicación hacen falta dos pulsaciones**: la primera captura `A` y la
placa queda en `ESPERA_B` (`LEDR[3:2]`=`01`, `LEDR7` encendido); la segunda
captura `B` y ejecuta. En `ESPERA_B`, `HEX3:HEX2` muestra en vivo el valor de
`SW[7:0]` que vas a capturar como `B`.

## 5. Cómo leer las salidas

Con el ejemplo `5! = 120 = 0x78`:

```
 HEX5   HEX4   HEX3   HEX2   HEX1   HEX0
  0      5      0      0      7      8
  │      │      │      │      └──────┘
  │      │      │      │        resultado = 0x0078 = 120
  │      │      └──────┘
  │      │           B = 0x0000 (no se usa en factorial)
  │      └── A / n = 0x0005
  └── nibble alto de A / n (0)
```

El modo **no** se muestra en los displays: se lee en `LEDR[1:0]`.

Los LEDs completan la información:

```
 LEDR8  LEDR7  LEDR6  LEDR5  LEDR4  LEDR3 LEDR2  LEDR1 LEDR0
  0      0      0      1      0     1     1      0     1
  │      │      │      │      │     └──┬──┘     └──┬──┘
  │      │      │      │      │      estado=11    modo=01 (factorial)
  │      │      │      │      └── cero=0
  │      │      │      └── válido=1 (resultado en FIN)
  │      │      └── ocupado=0
  │      └── espera B=0
  └── modo inválido=0
```

### Límites de 8 bits

El datapath es de **8 bits**: los resultados se truncan módulo 256.

- Factorial: usa `n = 1..5`. `5! = 120` cabe; `6! = 720 → 0xD0`.
- Suma: `S(22) = 253`; `S(23) = 276 → 0x14`.
- Multiplicación: usa valores cuyo producto no pase de 255 (por ejemplo
  `15×15 = 225`). `20×20 = 400 → 0x90`.
- `0!` **no** está contemplado como `1`: el microcódigo entra en un bucle de
  255 iteraciones y devuelve `0`. Usa `n ≥ 1`.

## 6. Lo que no se ve (y por qué)

| Señal | Por qué no se ve |
|---|---|
| `paso`, `ciclos` | cambian cada ciclo a 50 MHz (20 ns) |
| `out_en` | se activa en el paso final y dura tan poco que no se aprecia |
| las transiciones `LISTO → ESPERA_B → EJECUTANDO → FIN` (`ESPERA_B` solo en multiplicación) | `EJECUTANDO` dura menos de 1 µs; se ve el estado final en `LEDR[3:2]` |
| el orden interno de los estados | solo en GTKWave |

`LEDR[5]` sí se ve porque el resultado queda **latcheado** hasta la siguiente
ejecución. Para ver las señales internas:

```bash
scripts/vhdl-wave vhdl/datapath-2/salidas/tb_top_placa.vcd
```

## 7. Errores de interacción típicos

| Lo que haces | Por qué "no funciona" |
|---|---|
| Mueves `SW` y esperas que el **resultado** cambie solo | el display de `A/n` (o `B` en `ESPERA_B`) sí cambia en vivo, pero el resultado no se recalcula hasta pulsar `KEY0` |
| En multiplicación pulsas `KEY0` una sola vez | faltan las dos pulsaciones: `A` y luego `B` |
| Cambias `SW[9:8]` durante la ejecución | el modo se latchea al arrancar; el cambio se ignora |
| Mantienes `KEY0` pulsado esperando más ejecuciones | es detector de flanco: una pulsación = una ejecución |
| Pulsas `KEY0` durante la ejecución | se ignora; espera a `FIN` y vuelve a pulsar |
| Sueltas `KEY3` con `KEY0` ya pulsado | el envoltorio no arranca hasta que sueltes y vuelvas a pulsar `KEY0` |
| Pruebas `0!` | el microcódigo no lo trata como `1`; usa `n ≥ 1` |
| Esperas resultados mayores de 255 | el datapath es de 8 bits; se trunca módulo 256 |
| Buscas el operando en algún display después de `FIN` | `A` y `B` quedan latcheados en `HEX5:2`, no se refrescan con los switches |

## 8. Compilar y programar (todo con la GUI)

1. **Abrir**: doble clic en `top_placa.qpf` (o `File → Open Project`).
2. **Revisar pines** (opcional): `Assignments → Pin Planner`. Ya están los 67.
3. **Compilar**: `Processing → Start Compilation` (`Ctrl+L`), 1-3 minutos.
4. **Comprobar**: `Compilation Report → Flow Summary` (ALMs, registros, pines)
   y `Fitter → Resource Section`. Solo los **Error** son problema; los Warning
   de pines sin usar son normales.
5. **Programar**: `Tools → Programmer` →
   - `Hardware Setup…` → debe aparecer **USB-Blaster II**,
   - `Add File…` → `output_files/top_placa.sof`,
   - marcar **Program/Configure** y `Start`.

> El `.sof` se carga en la SRAM de la FPGA: **se pierde al apagar**. Para que
> arranque solo habría que generar un `.rbf` y grabarlo en la tarjeta SD, que no
> es parte de esta entrega.
>
> Si el Programmer no ve el cable, falta la regla udev del USB-Blaster:
> ver `docs/guia-fpga-de10.md` §5.

## 9. Recursos y tiempos

Rellenar tras la compilación en Quartus (GUI):

| Métrica | Valor |
|---|---|
| ALMs | _pendiente_ |
| Registros | _pendiente_ |
| Pines | _pendiente_ (deben ser los 67 del contrato) |
| Bloques de memoria | _pendiente_ |
| DSP | _pendiente_ |
| Fmax (Slow 1200 mV 85 °C, setup) | _pendiente_ (debe ser ≥ 50 MHz) |

El `.sdc` es imprescindible: sin él TimeQuest no conoce el periodo y analiza
como si el reloj fuera de 1 GHz, con *slack* negativo artificial.

## 10. Simular el envoltorio

```bash
scripts/vhdl-sim datapath-2 tb_top_placa
scripts/vhdl-wave vhdl/datapath-2/salidas/tb_top_placa.vcd
```

El testbench comprueba, sin placa: `S(5)`, `S(1)`, `S(3)`, `5!`, `3!`,
`4×3`, `15×15`, `7×0`, `0×5`, la visualización en vivo de `A` y `B`, el
resultado latcheado, una pulsación = una ejecución, el reset en marcha, el modo
`11` inválido, el cambio de modo durante la ejecución, el armado del pulsador
tras el reset y la re-ejecución desde `FIN` sin pulsar reset.

## 11. Decisiones de diseño

- **El control se mantiene en reset** en `LISTO`, `ESPERA_B` y `FIN`. Así la
  secuencia de dos pulsaciones de `KEY0` no consume `ext1` ni avanza la FSM
  hasta que `A` y `B` están capturadas.
- **El modo se latchea** en la primera pulsación y no cambia durante la
  ejecución.
- **El resultado se captura** en la transición `EJECUTANDO → FIN`, cuando
  `out_en = 1` y `dato_out` ya es estable.
- **No se derivan relojes**: todo funciona a 50 MHz y el resultado queda
  latcheado. No se usa `divisor` ni `antirrebote`.
- **`KEY0` pasa por `pulsador`**: un flanco = una acción. Un registro `armado`
  evita un pulso espurio si `KEY0` está pulsado al salir del reset.
- **Modo `11` inválido**: el envoltorio ignora la pulsación y avisa por
  `LEDR[8]`. El microcódigo original no tiene algoritmo para ese modo.
- **Reparto de displays**: los 6 HEX muestran los tres valores de 8 bits
  completos; modo y estado van en LEDR.

## 12. Antes de ir al laboratorio

- [ ] Llevar `output_files/top_placa.sof` en un pendrive o correo.
- [ ] Llevar esta guía impresa o en el móvil (los pasos 1-10 de §4).
- [ ] Llevar el repo (o al menos `vhdl/datapath-2/fpga/`,
      `vhdl/datapath-2/src/` y `vhdl/fpga-de10/src/`) por si hay que
      recompilar en el PC del laboratorio.
- [ ] Cable micro-USB: el del **USB-Blaster II** (no el UART).
