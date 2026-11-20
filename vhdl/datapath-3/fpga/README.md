# `datapath-3` en la DE10-Standard

Envoltorio de placa de **datapath-3**: permite ejecutar en la FPGA los cuatro
experimentos de la unidad (suma, factorial, multiplicación y Fibonacci) sin
simulador, cambiando de modo con los switches y disparando cada operación con
`KEY0`.

No sustituye al diseño: `src/` y `tb/` quedan intactos y siguen validándose con
`scripts/vhdl-sim`. Este directorio solo cablea la unidad a los periféricos.

```
fpga/
  top_placa.vhd        envoltorio (FSM de placa + control + datapath + displays)
  tb_top_placa.vhd     autochequeo del envoltorio (simulación)
  top_placa.qpf        proyecto Quartus (doble clic para abrir)
  top_placa.qsf        dispositivo, fuentes y los 67 pines
  top_placa.sdc        restricciones de tiempo (CLOCK_50 = 20 ns)
  output_files/        .sof generado (ignorado por git)
```

Qué hay dentro de la FPGA:

```
 SW[9:8] ─────────────► modo
 SW[7:0] ─────────────► operando A/n o B
 KEY0 ──► pulsador ───► ejecutar / capturar
 KEY3 ────────────────► reset

            ┌──────────────────────┐
            │ FSM del envoltorio   │
            │ LISTO/ESPERA_B/...   │
            └───────┬──────────────┘
                    │ modo, ext_data
                    ▼
             control ◄──── paso, fin
                │
                ▼
             datapath ────► dato_out ────► registro de resultado
                │                              │
                └──────────► HEX / LEDR ◄──────┘
```

La unidad original no se modifica: el envoltorio mantiene `control` y
`datapath` en reset en `LISTO`, `ESPERA_B` y `ARRANQUE`, y en `FIN` los deja
parados con `out_en = 1` para conservar el resultado.

---

# Guía de uso — día de la prueba

## 1. Controles

| Elemento | Función |
|---|---|
| `SW[9:8]` | modo: `00` suma, `01` factorial, `10` multiplicación, `11` Fibonacci |
| `SW[7:0]` | operando `n` (suma/factorial/Fibonacci) o `A`/`B` (multiplicación) |
| `KEY0` | ejecutar / capturar. En multiplicación: 1.ª pulsación captura `A`, 2.ª captura `B` y ejecuta |
| `KEY1` | sin uso |
| `KEY2` | sin uso |
| `KEY3` | reset general (activo a nivel bajo: pulsar) |

Los `KEY` están activos a nivel bajo, pero el envoltorio lo resuelve: tú solo
pulsas. `KEY0` pasa por `pulsador`: **una pulsación = una operación**.

## 2. Qué se ve

| Salida | Significado |
|---|---|
| `HEX5:HEX4` | operando `A` o `n`, en hexadecimal (8 bits) |
| `HEX3:HEX2` | operando `B`, en hexadecimal (8 bits; `00` en modos de un operando) |
| `HEX1:HEX0` | resultado, en hexadecimal (8 bits) |
| `LEDR[1:0]` | modo: `00` suma, `01` factorial, `10` multiplicación, `11` Fibonacci |
| `LEDR[3:2]` | estado: `00` listo, `01` esperando `B`, `10` ocupado, `11` fin |
| `LEDR4` | cero del resultado, latcheado al terminar |
| `LEDR5` | resultado válido (encendido en `FIN`) |
| `LEDR6` | ocupado: `ARRANQUE`, `EJECUTANDO` o `CAPTURA` (dura microsegundos) |
| `LEDR7` | esperando el segundo operando `B` (multiplicación) |
| `LEDR8` | `out_en` del buffer de salida |
| `LEDR9` | apagado |

En `LISTO` los displays muestran lo que hay en los switches (`SW[7:0]`), para
que puedas comprobar el valor antes de pulsar. En `ESPERA_B` el display `B`
muestra en vivo el valor de `SW[7:0]`. En `FIN` todo queda latcheado: mover los
switches **no** cambia el resultado.

## 3. Flujo de uso

```
 ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
 │ 1. Elige modo   │   │ 2. Pon el       │   │ 3. Pulsa KEY0   │   │ 4. Lee HEX y    │
 │    en SW[9:8]   │──►│    operando en  │──►│    y suelta     │──►│    LEDR5        │
 │                 │   │    SW[7:0]      │   │                 │   │                 │
 └─────────────────┘   └─────────────────┘   └─────────────────┘   └─────────────────┘
                                                                          │
        ┌─────────────────────────────────────────────────────────────────┘
        ▼
 ┌─────────────────┐
 │ 5. Repite con   │
 │    otro modo o  │
 │    pulsa KEY3   │
 └─────────────────┘
```

> La entrada se captura **al pulsar `KEY0`**. Si cambias los switches mientras
> la operación está en marcha, el modo y los operandos ya están latcheados y no
> afectan al resultado.

## 4. Guion de demostración

### 4.1 Suma `S(5) = 15`

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | `SW[9:8] = 00`, `SW[7:0] = 05` (`SW2` y `SW0` en ON) | `HEX5:4 = 05`, `HEX3:2 = 00`, `HEX1:0 = 00` |
| 2 | Pulsar y soltar `KEY0` | `LEDR3:2 = 11` (fin), `LEDR5` encendido |
| 3 | Leer displays | `HEX5:4 = 05`, `HEX3:2 = 00`, `HEX1:0 = 0F` |

`0F` es 15 en hexadecimal: `S(5) = 5·6/2 = 15`.

### 4.2 Factorial `5! = 120`

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | Pulsa `KEY3` | estado `00` (listo), resultado `00` |
| 2 | `SW[9:8] = 01`, `SW[7:0] = 05` | `HEX5:4 = 05` |
| 3 | Pulsar y soltar `KEY0` | `LEDR5` encendido |
| 4 | Leer displays | `HEX1:0 = 78` (`120 = 0x78`) |

### 4.3 Multiplicación `4 × 3 = 12`

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | Pulsa `KEY3`; `SW[9:8] = 10`, `SW[7:0] = 04` | `HEX5:4 = 04` |
| 2 | Pulsar y soltar `KEY0` | `LEDR7` encendido: esperando `B`; `HEX3:2 = 04` (vivo) |
| 3 | Cambia `SW[7:0] = 03` | `HEX3:2 = 03`; `HEX5:4` sigue `04` |
| 4 | Pulsar y soltar `KEY0` | `LEDR7` se apaga, `LEDR5` se enciende al terminar |
| 5 | Leer displays | `HEX5:4 = 04`, `HEX3:2 = 03`, `HEX1:0 = 0C` |

`0C` es 12. Si el resultado es cero (`7 × 0` o `0 × 5`), además se enciende
`LEDR4`.

### 4.4 Fibonacci `F(13) = 233`

| Paso | Acción | Resultado esperado |
|---|---|---|
| 1 | Pulsa `KEY3`; `SW[9:8] = 11`, `SW[7:0] = 0D` (13) | `HEX5:4 = 0D` |
| 2 | Pulsar y soltar `KEY0` | `LEDR5` encendido |
| 3 | Leer displays | `HEX5:4 = 0D`, `HEX3:2 = 00`, `HEX1:0 = E9` |

`E9` es 233. `F(0) = 0` también funciona y enciende `LEDR4`; `F(1) = 1`.

## 5. Cómo leer las salidas

Cada display es **un nibble** (4 bits). Se muestran tres campos de 8 bits:

```
 HEX5   HEX4   HEX3   HEX2   HEX1   HEX0
  0      5      0      0      0      F
  └──────┴──────┘      │      └──────┴──────┘
       A/n = 0x05      │        resultado = 0x0F
                       └── B = 0x00
```

- `HEX5:4` y `HEX3:2` son los operandos; `HEX1:0` es el resultado.
- El resultado es de 8 bits: si la operación real supera `255`, se muestra el
  byte bajo y se pierde el acarreo. Por ejemplo `15 × 15 = 225` sí cabe (`E1`),
  pero `20 × 20 = 400` mostraría `90` (el byte bajo).
- En los modos de un solo operando, `HEX3:2` vale `00`.
- `LEDR4` es el **cero lógico** del resultado: encendido si el resultado es `0`.

## 6. Lo que no se ve

| Señal | Por qué no se ve |
|---|---|
| `LEDR6` (ocupado) | dura entre 33 y 145 ciclos según el modo (0,7-2,9 µs a 50 MHz) |
| `LEDR3:2` cambiando | el estado pasa por `ARRANQUE`, `EJECUTANDO` y `CAPTURA` en microsegundos |
| `LEDR8` (`out_en`) | solo se enciende al final, junto con `LEDR5` |
| `paso` y `ciclos` | son internos y no están cableados a ningún pin |

`LEDR5`, `LEDR4`, `HEX1:0`, `HEX5:4` y `HEX3:2` sí se ven porque el resultado se
queda latcheado en `FIN`. Para ver la evolución interna, simula con
`scripts/vhdl-sim datapath-3 tb_top_placa` y abre el `.vcd` con
`scripts/vhdl-wave`.

## 7. Errores típicos

| Lo que haces | Por qué "no funciona" |
|---|---|
| Mueves los switches y esperas que el resultado cambie solo | hay que pulsar `KEY0`; el diseño muestrea al pulsar, no al mover |
| Mantienes `KEY0` pulsado esperando que repita | `pulsador` detecta flanco: una pulsación = una ejecución |
| En multiplicación pulsas `KEY0` una sola vez | faltan los dos operandos: tras la primera pulsación queda en `ESPERA_B` (`LEDR7`) |
| Cambias de modo durante la ejecución y esperas otro resultado | el modo y los operandos se latchean al pulsar `KEY0` |
| Pruebas `0!` | el factorial está pensado para `n >= 1`; `0!` no está garantizado en esta unidad |
| Pruebas `6!` o `F(14)` | el resultado real no cabe en 8 bits y se muestra truncado |
| Pulsas `KEY1` o `KEY2` | no están conectados: no hacen nada en esta unidad |
| Mueves `SW` después de ver el resultado | en `FIN` los displays están latcheados; no cambian hasta la siguiente pulsación |
| Pulsas `KEY0` durante el reset | se ignora a propósito; suelta `KEY0`, suelta `KEY3` y vuelve a pulsar |
| Pulsas `KEY0` mientras `LEDR6` está encendido | la operación en curso no se interrumpe; espera a `LEDR5` y vuelve a pulsar |

## 8. Compilar y programar

1. **Abrir**: doble clic en `top_placa.qpf`.
2. **Compilar**: `Processing → Start Compilation` (`Ctrl+L`).
3. **Comprobar**: en `Compilation Report → Flow Summary` deben aparecer los
   67 pines y no debe haber errores; en `TimeQuest` el reloj `clk` está
   restringido a 20 ns (50 MHz).
4. **Verificar**: debe generarse `output_files/top_placa.sof`.

> Esta entrega se valida con la simulación y con que Quartus genere el `.sof`;
> no es necesario programar la placa. Si se va a usar la DE10-Standard, el flujo
> de programación con `Tools → Programmer` está en
> `docs/guia-fpga-de10.md` §4.5.

No se publican métricas de recursos ni de `Fmax` porque Quartus no está
instalado en el entorno de desarrollo; se rellenan al compilar en el PC del
laboratorio.

## 9. Simular el envoltorio

```bash
scripts/vhdl-sim datapath-3 tb_top_placa
scripts/vhdl-wave vhdl/datapath-3/salidas/tb_top_placa.vcd
```

El testbench comprueba, sin placa: reset, los cuatro modos, los operandos `A`/`B`,
la captura de `dato_out`, el flag de cero, una pulsación = una ejecución, el
reset en mitad de una operación y que `KEY0` pulsado al salir del reset no
dispara nada.

## 10. Decisiones de diseño

- **El control se mantiene en reset** en `LISTO`, `ESPERA_B` y `ARRANQUE`.
  `ARRANQUE` dura un ciclo para que el control cargue la base
  `paso = modo × 32` con el modo ya latcheado.
- **El resultado se captura en `CAPTURA`**, un ciclo después de que `fin` se
  active: en ese flanco la última microinstrucción ya ha escrito el acumulador
  y `dato_out` (con `out_en = 1`) es estable.
- **En `FIN` no se resetea el control**: queda parado con `fin = 1` y
  `out_en = 1`, y así el buffer de salida conserva el resultado.
- **No se derivan relojes**: todo funciona a 50 MHz con un tick de habilitación
  lógico; el resultado queda latcheado y no hace falta `divisor`.
- **`KEY0` pasa por `pulsador`**: un flanco = una acción. Un registro `armado`
  evita el pulso espurio si `KEY0` está pulsado al salir del reset.
- **No se usa `antirrebote`** para los switches: se leen de forma síncrona al
  pulsar `KEY0`; los `KEY` de la DE10 ya llevan Schmitt.

## 11. Antes de ir al laboratorio

- [ ] Llevar `output_files/top_placa.sof` en un pendrive o correo.
- [ ] Llevar esta guía impresa o en el móvil (guion de §4).
- [ ] Llevar el repo (o al menos `fpga/` y `vhdl/fpga-de10/src/`).
- [ ] Cable micro-USB: el del **USB-Blaster II** (no el UART).
- [ ] Si se va a programar: encender la placa antes de abrir `Hardware Setup…`.
