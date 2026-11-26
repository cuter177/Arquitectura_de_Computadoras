# Proyecto final en la DE10-Standard

Pone en la placa el mismo motor de microcódigo genérico con tres programas:
multiplicación **shift-add**, **popcount** y control de un motor paso a paso
**NEMA 17 (Steren MOT-200)**. Los dos primeros se ejecutan sobre el datapath 3
descrito a nivel RTL; el tercero gobierna hardware externo a través de un
driver A4988/DRV8825. Todo se elige con `SW[9:8]`.

```
fpga/
  top_placa.vhd        envoltorio: FSM de captura, selección de programa,
                       step/DIR para el motor y mapeo de displays/LEDs
  tb_top_placa.vhd     comprueba los tres programas desde KEY/SW y verifica
                       displays, DIR/EN/MS y los pulsos STEP
  top_placa.qpf        proyecto Quartus (doble clic para abrir)
  top_placa.qsf        dispositivo, fuentes y pines (incluye GPIO_0)
  top_placa.sdc        restricciones de tiempo (CLOCK_50 = 20 ns)
  output_files/        .sof generado (ignorado por git)
```

## Controles

| Elemento | Función |
|---|---|
| `SW[9:8]` | programa: `00` shift-add, `01` popcount, `10` motor NEMA 17 |
| `SW[7:0]` | A (shift-add), x (popcount) o número de pasos 1..255 (motor) |
| `KEY0` | ejecutar/capturar. En shift-add: 1.ª pulsación captura A, 2.ª captura B y arranca |
| `KEY1` | invertir el sentido del motor (solo modo `10`) |
| `KEY3` | reset general (pulsador activo a nivel bajo) |

## Qué se ve

| Salida | Significado |
|---|---|
| `HEX5:HEX4` | operando A / byte x / pasos programados (8 bits en hexadecimal) |
| `HEX3:HEX2` | operando B en shift-add; pasos restantes en modo motor; `00` en popcount |
| `HEX1:HEX0` | resultado: producto, conteo de unos o pasos restantes |
| `LEDR[1:0]` | modo activo (salvo en motor en ejecución, donde se usan para fases) |
| `LEDR[3:2]` | estado: `00` listo, `01` esperando B, `10` ocupado, `11` fin |
| `LEDR[4]` | flag `cero` latcheado al terminar |
| `LEDR[5]` | resultados válidos (estado FIN) |
| `LEDR[6]` | ocupado |
| `LEDR[7]` | esperando el segundo operando (shift-add) |
| `LEDR[8]` | sentido del motor (`1` = inverso) |
| `LEDR[3:0]` | **en modo motor en ejecución**: patrón de fases de las bobinas |
| `GPIO_0[0]` | `STEP` del driver (un pulso por paso) |
| `GPIO_0[1]` | `DIR` del driver |
| `GPIO_0[2]` | `EN` del driver (activo a nivel bajo; se deja a `0`) |
| `GPIO_0[3:5]` | `MS1/MS2/MS3` = `000` (paso completo) |

## Flujo de uso

```
  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
  │ 1. Elegir modo │──►│ 2. Poner SW    │──►│ 3. KEY0 y leer │
  │    con SW[9:8] │   │   [7:0] (dato) │   │   HEX / LEDR   │
  └────────────────┘   └────────────────┘   └────────────────┘
```

Los resultados que importan quedan **latcheados** en `FIN`: mover los switches
después no los cambia. Para repetir, pulsa `KEY0` otra vez (o `KEY3` para
empezar de cero).

## Guion de demostración

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | `KEY3`, `SW = 00 00000100` (modo 00, A=4) | `LEDR[1:0]=00`, estado `00` |
| 2 | `KEY0` | estado `01` (esperando B); HEX5:4 muestra `04` |
| 3 | `SW = 00 00000011` (B=3), `KEY0` | estado `10` (ocupado) |
| 4 | Esperar a `LEDR[5]=1` | HEX1:0 = `0C` (12 = 4×3) |
| 5 | `KEY3`, `SW = 01 10100101` (modo 01, x=A5), `KEY0` | HEX1:0 = `04` (popcount de A5) |
| 6 | `KEY3`, `SW = 10 00000100` (modo 10, 4 pasos), `KEY0` | `LEDR[3:0]` recorre `3→6→C→9`; 4 pulsos en `GPIO_0[0]` |
| 7 | `KEY1` antes del paso 6 | `LEDR[8]=1`, `DIR=1`, fases en orden inverso |

## Cómo leer las salidas

- Los displays son hexadecimales y están activos a nivel bajo (`hex7seg`).
  `0C` son dos dígitos: HEX1=`0`, HEX0=`C`.
- En shift-add, HEX5:4 = A y HEX3:2 = B; en popcount solo se usa HEX5:4.
- En modo motor, HEX5:4 = pasos programados y HEX3:2 = pasos que quedan; al
  terminar HEX1:0 muestra `00` (contador agotado). Lo interesante son las
  fases en LEDR y los pulsos STEP por GPIO.
- La secuencia de fases es de **dos fases activas** (más par que una sola):
  adelante `0011 → 0110 → 1100 → 1001`, atrás la inversa.

## Cableado del motor NEMA 17

El Steren MOT-200 es **bipolar de 2 fases**: 1.8°/paso (200 pasos/vuelta),
3.1 V nominales, **1.7 A por fase**, 0.59 N·m, resistencia de fase 1.8 Ω e
inductancia 3.8 mH. **Un pin de la FPGA no puede alimentarlo**: hace falta un
driver con fuente externa.

| DE10-Standard | Driver A4988 / DRV8825 | Motor |
|---|---|---|
| `GPIO_0[0]` (`PIN_W15`) | `STEP` | — |
| `GPIO_0[1]` (`PIN_AK2`) | `DIR` | — |
| `GPIO_0[2]` (`PIN_Y16`) | `ENABLE` (activo bajo) | — |
| `GPIO_0[3:5]` (`PIN_AK3`, `PIN_AJ1`, `PIN_AJ2`) | `MS1/MS2/MS3` | — |
| — | `1A, 1B, 2A, 2B` | dos bobinas del motor |
| — | `VMOT` | fuente externa (p. ej. 12 V) |
| GND de la placa | GND | GND |

Ajusta el límite de corriente del driver a **1.7 A o menos** antes de conectar
el motor, y comparte masa entre la fuente, el driver y la placa. El `.sof` se
pierde al apagar (modo JTAG): hay que volver a programarlo.

## Lo que no se ve

El `paso` del microcódigo, `wr_acc`, `out_en` y el `cero` interno duran
microciclos de 50 MHz (o un tick de 100 Hz en el modo motor) y no se aprecian a
simple vista. Para inspeccionarlos, ejecuta `scripts/vhdl-sim proyecto-final
tb_top_placa` y abre el VCD con `scripts/vhdl-wave`.

## Errores típicos

| Lo que haces | Por qué "no funciona" |
|---|---|
| Mover `SW` sin pulsar `KEY0` | las entradas se capturan solo en el flanco de `KEY0` |
| Pulsar `KEY0` una sola vez en shift-add | faltaba capturar B: el diseño está en `LEDR[3:2]=01` |
| Mantener `KEY0` pulsado | un flanco = una acción; suelta y vuelve a pulsar |
| Mirar `LEDR[1:0]` en modo motor | en ejecución esos LEDs muestran las fases, no el modo |
| Conectar el motor directo a GPIO | la FPGA da 3.3 V lógicos, no los 1.7 A por fase |
| `STEP` sin pulso | comprueba `EN=0`, `VMOT` presente y que el modo sea `10` |
| Displays en blanco o invertidos | son ánodo común: el segmento se enciende con `0` |

## Compilar y programar

1. **Abrir**: doble clic en `top_placa.qpf`.
2. **Compilar**: `Processing → Start Compilation` (`Ctrl+L`). Revisa
   `Flow Summary` y que no haya *Ignored assignments* sobre `step_out`,
   `dir_out`, `en_out` ni `ms_out`.
3. **Programar**: `Tools → Programmer` → `Hardware Setup…` (USB-Blaster II),
   `Add File…` → `output_files/top_placa.sof`, marcar **Program/Configure** y
   `Start`.

El tick del motor es de 100 Hz (200 pasos ≈ 2 s por vuelta). Se puede cambiar
con el genérico `FREC_MOTOR_HZ` de `top_placa.vhd` y recompilar.

## Antes de ir al laboratorio

- [ ] Llevar `output_files/top_placa.sof` en un pendrive o correo.
- [ ] Llevar esta guía impresa o en el móvil.
- [ ] Llevar el repo (o al menos `fpga/` y `vhdl/fpga-de10/src/`).
- [ ] Cable micro-USB al conector **USB-Blaster II** (no al UART).
- [ ] Si se prueba el motor: driver, fuente externa y cableado de la tabla.
- [ ] Tras programar: `KEY3`, primera lectura y comprobar que responde.
