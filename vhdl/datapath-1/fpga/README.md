# datapath-1 en la DE10-Standard

Envoltorio de placa de **datapath-1**: pone el datapath de 8 bits (MUX de
entrada → ALU → registro → buffer de salida, con Q realimentado a la ALU) en la
FPGA para ejecutar las operaciones sin simulador.

No sustituye al diseño: `src/` y los testbenches originales quedan intactos y
siguen validándose con `scripts/vhdl-sim`. Lo único que hace este directorio es
cablear el datapath a los periféricos de la placa.

```
fpga/
  top_placa.vhd        envoltorio (pulsadores, registro de OE/M y displays)
  top_placa.qpf        proyecto Quartus (doble clic para abrir)
  top_placa.qsf        dispositivo, fuentes y los 67 pines
  top_placa.sdc        restricciones de tiempo (CLOCK_50 = 20 ns)
  output_files/        .sof generado (ignorado por git)
tb/
  tb_top_placa.vhd     autochequeo del envoltorio (simulación)
```

Qué hay dentro de la FPGA:

```
 SW[7:0] ─────────────► dato externo (A)
 SW[9:8] ─────────────► operación de la ALU (C1:C0; C2 = 0)

 KEY0 ─► pulsador ─► carga F_ALU en Q (un flanco = una carga)
 KEY1 ─► pulsador ─► alterna OE
 KEY2 ─► pulsador ─► alterna M
 KEY3 ─────────────► reset

              ┌────────────────────┐
              │ datapath original  │  MUX -> ALU -> registro -> buffer
              └─────────┬──────────┘
                        │ Q, F_ALU
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
| `SW[7:0]` | entrada | **dato externo** (operando A de la ALU) |
| `SW[9:8]` | entrada | **operación**: `00` A+B, `01` 2n+x, `10` n+1, `11` reservada |
| `KEY0` | entrada | carga `F_ALU` en `Q`; un clic = una carga |
| `KEY1` | entrada | alterna `OE` (salida habilitada / deshabilitada) |
| `KEY2` | entrada | alterna `M` (`1` usa `SW[7:0]`, `0` usa cero) |
| `KEY3` | entrada | reset general |
| `LEDR[7:0]` | salida | **Q** en binario; se muestra siempre, aunque `OE=0` |
| `LEDR8` | salida | estado de `M` |
| `LEDR9` | salida | estado de `OE` |
| `HEX5:HEX4` | salida | **dato externo** `SW[7:0]` en hexadecimal |
| `HEX3:HEX2` | salida | **F_ALU** en hexadecimal (resultado combinacional actual) |
| `HEX1:HEX0` | salida | **Q** en hexadecimal; se apagan si `OE=0` |

Los `KEY` están activos a nivel bajo (pulsar = 0), pero lo resuelve el
envoltorio: tú solo pulsas.

> **OE en esta placa**: el buffer tri-estado original no se conecta a ningún
> periférico. `OE=0` apaga `HEX1:0` y `LEDR9`, pero **`LEDR[7:0]` sigue
> mostrando Q**. Es una decisión de visualización, no un tri-estado real.

## 2. El bucle de interacción

```
 ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
 │ 1. Pon dato y   │   │ 2. Pulsa KEY0   │   │ 3. Lee LEDR/HEX │   │ 4. Repite o     │
 │    operación en │──►│    y suelta     │──►│                 │──►│    cambia de    │
 │    SW           │   │                 │   │                 │   │    operación    │
 └─────────────────┘   └─────────────────┘   └─────────────────┘   └─────────────────┘
```

> El dato se captura **en el instante en que pulsas `KEY0`**. Si mueves los
> switches después, `Q` no cambia hasta la próxima carga; solo cambia el
> `F_ALU` que se ve en `HEX3:2`.

## 3. Escribir el dato y la operación con los switches

Cada switch de `SW[7:0]` vale un peso binario; los que uses, en **ON** (arriba),
los demás abajo:

| Switch | `SW0` | `SW1` | `SW2` | `SW3` | `SW4` | `SW5` | `SW6` | `SW7` |
|---|---|---|---|---|---|---|---|---|
| Vale | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 |

La operación se elige con `SW[9:8]`:

| Operación | `SW9` | `SW8` | `C2:C0` | Resultado de la ALU |
|---|---|---|---|---|
| A+B (`00`) | abajo | abajo | `000` | `F = Q + A` |
| 2n+x (`01`) | abajo | arriba | `001` | `F = 2·Q + A` |
| n+1 (`10`) | arriba | abajo | `010` | `F = Q + 1` (ignora A) |
| Reservada (`11`) | arriba | arriba | `011` | `F = 0` |

`C2` se fija a `0` en el envoltorio: por eso solo se usan cuatro códigos. Los
tres primeros son las operaciones definidas de la ALU; el cuarto es la
reservada, que devuelve `0`.

`M` decide qué entra como operando A:

| `M` | Operando A | Cuándo se usa |
|---|---|---|
| `1` (LEDR8 encendido) | `SW[7:0]` | operaciones con dato externo |
| `0` (LEDR8 apagado) | `0` | operaciones solo con `Q` |

> Con `M=0` y la operación `A+B` (`00`), cargar da `Q+0 = Q`: parece que no
> pasa nada, pero sí se ha cargado el mismo valor.

## 4. Guion paso a paso

| Paso | Tú haces | La placa muestra | Qué significa |
|---|---|---|---|
| 1 | Enciendes y pulsas `KEY3` | `Q=00`, `M=1`, `OE=1`; `HEX5:0`=`00 00 00` | todo reiniciado |
| 2 | `SW[7:0]`=`05` (`SW0`+`SW2`), operación `00`, `KEY0` | `LEDR[7:0]`=`05`, `HEX1:0`=`05`; `HEX3:2`=`0A` | carga `Q=5`; después `F=5+5=0x0A` |
| 3 | Operación `01` (`SW8` ON), `KEY0` | `LEDR[7:0]`=`0F`, `HEX1:0`=`0F`; `HEX3:2`=`23` | `Q=2·5+5=15`; después `F=2·15+5=0x23` |
| 4 | Operación `10` (`SW9` ON), `KEY0` | `LEDR[7:0]`=`10`, `HEX1:0`=`10`; `HEX3:2`=`11` | `Q=15+1=16`; después `F=17` |
| 5 | Operación `11` (`SW8`+`SW9`), `KEY0` | `LEDR[7:0]`=`00`, `HEX1:0`=`00`; `HEX3:2`=`00` | operación reservada: `F=0` |
| 6 | `KEY3`; operación `00`, `SW[7:0]`=`05`, `KEY0`; `KEY2`; operación `01`, `SW[7:0]`=`07` | `LEDR8` se apaga; `HEX3:2`=`0A` | con `M=0`, `F=2·5+0=0x0A` (no usa `07`) |
| 7 | `KEY0` | `LEDR[7:0]`=`0A`, `HEX1:0`=`0A`; `HEX3:2`=`14` | carga `Q=10`; después `F=2·10+0=0x14` |
| 8 | `KEY2` (vuelve `M=1`), `KEY0` | `LEDR[7:0]`=`1B`, `HEX1:0`=`1B`; `HEX3:2`=`3D` | `Q=2·10+7=27`; después `F=2·27+7=0x3D` |
| 9 | `KEY1` | `LEDR9` se apaga; `HEX1:0` se apagan; `LEDR[7:0]` sigue `1B` | `OE=0`: solo se ocultan los displays de Q |
| 10 | `KEY1` otra vez | `LEDR9` se enciende; `HEX1:0`=`1B` | `OE=1` restaurado |
| 11 | `KEY3` | `Q=00`, `M=1`, `OE=1` | reset |

**El valor cargado está en `LEDR[7:0]` y `HEX1:0`**, no en `HEX3:2`. Tras
pulsar `KEY0`, `HEX3:2` pasa a mostrar el `F_ALU` de la *siguiente* operación,
calculado con el nuevo `Q`.

## 5. Cómo leer las salidas

Con el estado del paso 8 (`Q=0x1B`, `SW[7:0]=0x07`, operación `01`, `M=1`):

```
 HEX5   HEX4   HEX3   HEX2   HEX1   HEX0
  0      7      3      D      1      B
  │      │      │      │      └──────┘
  │      │      │      │        Q = 0x1B = 27
  │      │      └──────┘
  │      │        F_ALU = 0x3D = 61 = 2·27 + 7
  │      └── dato externo = 0x07
  └── nibble alto del dato externo (0)
```

Los LEDs completan la información:

```
 LEDR9 LEDR8  LEDR7..LEDR0
  OE     M        Q
   1     1      0x1B
```

- `LEDR[7:0]` muestra `Q` siempre, también con `OE=0`.
- `LEDR8` indica `M`.
- `LEDR9` indica `OE`.

### Límites de 8 bits

El datapath es de **8 bits**: los resultados se truncan módulo 256. Por
ejemplo, `2n+x` con `Q=0x80` y `x=0x80` da `0x180`, que se ve como `0x80`.
La ALU no tiene banderas de desbordamiento.

## 6. Lo que no se ve (y por qué)

| Señal | Por qué no se ve |
|---|---|
| `F_ALU` "del momento de la carga" | es combinacional: tras cargar cambia con el nuevo `Q`; el valor cargado queda en `Q` |
| pulsos internos de `pulsador` y `armado` | duran un ciclo a 50 MHz (20 ns) |
| el buffer tri-estado original | `salida` no se conecta a la placa; `OE` se representa con `HEX1:0` y `LEDR9` |
| el orden exacto de las cargas | solo en GTKWave (`scripts/vhdl-wave`) |

## 7. Errores de interacción típicos

| Lo que haces | Por qué "no funciona" |
|---|---|
| Mueves `SW` y esperas que `Q` cambie solo | hay que pulsar `KEY0`; los switches no disparan la carga |
| Mantienes `KEY0` pulsado esperando más cargas | es detector de flanco: una pulsación = una carga |
| Miras `HEX3:2` después de `KEY0` buscando el valor cargado | `HEX3:2` es el `F_ALU` actual; el valor cargado está en `HEX1:0` y `LEDR` |
| Con `M=0` y operación `00` pulsas `KEY0` esperando borrar `Q` | carga `Q+0`, es decir, el mismo valor; para borrar usa `KEY3` |
| Pulsas `KEY1` y esperas que se apague `LEDR[7:0]` | `OE` solo apaga `HEX1:0` y `LEDR9`; los LEDs de `Q` siguen |
| Pulsas `KEY2` y olvidas que `M=0` | las operaciones dejan de usar `SW[7:0]` como operando A |
| Buscas ocho operaciones con `SW[9:8]` | solo hay dos switches; `C2=0` y las operaciones alcanzables son cuatro |
| Sueltas `KEY3` con `KEY0` ya pulsado | la pulsación se ignora hasta soltar y volver a pulsar `KEY0` |
| Esperas un tri-estado real en la placa | el buffer de salida no está cableado a los periféricos |

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
scripts/vhdl-sim datapath-1 tb_top_placa
scripts/vhdl-wave vhdl/datapath-1/salidas/tb_top_placa.vcd
```

El testbench comprueba, sin placa: reset, visualización en vivo de dato y
`F_ALU`, carga con `A+B`, `2n+x`, `n+1` y la operación reservada, el efecto
funcional de `M=0` frente a `M=1`, el apagado y restauración de `HEX1:0` con
`OE`, una pulsación mantenida = una sola carga, la pulsación ignorada durante
el reset y el reset con `Q` distinto de cero.

## 11. Decisiones de diseño

- **`KEY0` pasa por `pulsador`**: un flanco = una carga. Un registro `armado`
  evita una carga espuria si `KEY0` está pulsado al salir del reset.
- **`OE` y `M` se latchean** y se alternan con `KEY1` y `KEY2`; su estado se ve
  en `LEDR9` y `LEDR8`.
- **`OE` no apaga `LEDR[7:0]`**: el buffer tri-estado original (`salida`) queda
  sin conectar a la placa; `OE` solo oculta `HEX1:0` y se refleja en `LEDR9`.
- **`C2` se fija a 0**: `SW[9:8]` selecciona `C1:C0` y cubre las tres
  operaciones definidas más la reservada.
- **`M=1` usa `SW[7:0]`; `M=0` usa cero**, igual que el MUX de entrada original.
- **No se derivan relojes**: todo funciona a 50 MHz; los resultados quedan
  latcheados en `Q` y no se usa `divisor`.
- **La ALU es combinacional y sin banderas**: los desbordamientos son
  silenciosos y el resultado se trunca a 8 bits.

## 12. Antes de ir al laboratorio

- [ ] Llevar `output_files/top_placa.sof` en un pendrive o correo.
- [ ] Llevar esta guía impresa o en el móvil (los pasos 1-11 de §4).
- [ ] Llevar el repo (o al menos `vhdl/datapath-1/fpga/`,
      `vhdl/datapath-1/src/`, `vhdl/datapath-1/tb/` y `vhdl/fpga-de10/src/`)
      por si hay que recompilar en el PC del laboratorio.
- [ ] Cable micro-USB: el del **USB-Blaster II** (no el UART).
