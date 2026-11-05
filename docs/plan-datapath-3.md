# Plan de trabajo — Unidad `datapath-3`

> Plan completo para la unidad **datapath-3**: implementación VHDL del Datapath 3
> (diagrama de la asignatura) y validación experimental de cuatro algoritmos:
> suma de los primeros n números, factorial de n, multiplicación A × B y
> Fibonacci de n.
>
> Reglas aplicables: `AGENTS.md` (raíz), `vhdl/AGENTS.md`, `reportes/AGENTS.md`
> y `docs/guia-git.md`.
>
> Imágenes de referencia (copiadas al repo):
> `docs/imagenes-datapath-3/datapath-3-diagrama.jpeg` (diagrama) y
> `docs/imagenes-datapath-3/datapath-3-alu-tabla.jpeg` (tabla de la ALU).

---

## 1. Objetivo

Demostrar experimentalmente, mediante simulación GHDL, que el Datapath 3 puede
resolver con sus módulos y operaciones disponibles:

| # | Experimento | Ejemplo | Esperado |
|---|---|---|---|
| 1 | S(n) = 1 + 2 + … + n | n = 5 | 15 |
| 2 | n! = 1 × 2 × … × n | n = 5 | 120 |
| 3 | P = A × B | A = 4, B = 3 | 12 |
| 4 | F(n) con F(0)=0, F(1)=1 | n = 7 | 13 |

## 2. Estado de partida (verificado)

- `vhdl/datapath-3/src/` y `tb/` **vacíos** (solo `.gitkeep`): no hay
  implementación previa que sustituir.
- `reportes/datapath-3/main.tex` es la plantilla sin rellenar;
  `referencias.bib` solo tiene 2 entradas (faltan ≥13 para las ≥15).
- Unidad modelo: `mapeo-memoria` (estructura de carpetas, estilo de tbs y
  workflow de capturas VCD → PNG).
- El CI (`.github/workflows/ci.yml`) ejecuta en cada PR `scripts/vhdl-analizar`
  por unidad y **todos** los `tb_*.vhd` que existan → cada testbench debe
  pasar desde su PR y debe terminar (sin bucles infinitos de simulación).
- Imágenes del datapath obtenidas de la asignatura y versionadas en
  `docs/imagenes-datapath-3/`.

## 3. Decisiones acordadas

| Decisión | Valor | Motivo |
|---|---|---|
| Ancho de palabra | **8 bits sin signo** (`[0;7]` en el diagrama) | Etiquetado en la imagen del mux superior |
| Unidad de control | **FSM secuencial** (`control.vhd`) con ROM de microinstrucciones | Los 4 algoritmos son multi-ciclo; se describe aparte (restricción 5) |
| Flag de condición | **`detector_cero`** (1 bit) sobre la salida del shifter | Sin él ningún bucle puede terminar; añadido con justificación explícita |
| Multiplicación | **sumas repetidas** (rutina `mult` compartida) | La ALU no tiene multiplicar; el shifter queda como mejora futura |
| Alcance | **Solo VHDL + validación** en esta fase | El reporte LaTeX va después, en ramas `reporte/datapath-3/*` |
| Convención Fibonacci | **F(0)=0, F(1)=1**; se calcula F(n) | Fijada en el enunciado y usada de forma consistente |

### Límites por desbordamiento (8 bits, sin flag de acarreo)

| Experimento | Entrada máxima | Motivo |
|---|---|---|
| Suma 1..n | n ≤ 22 | S(22)=253; S(23)=276 > 255 |
| Factorial | n ≤ 5 (y n ≥ 1) | 5!=120; 6!=720 > 255 |
| A × B | A, B ≤ 15 (y ≥ 0) | 15×15=225; 16×16=256 > 255 |
| Fibonacci | 0 ≤ n ≤ 13 | F(13)=233; F(14)=377 > 255 |

Los desbordamientos son **silenciosos** (la ALU no expone acarreo): se documenta
como limitación.

---

## 4. Etapa 1 — Análisis de la arquitectura

### 4.1 Diagrama reconstruido

```
        EXT1 ─┐                                   ┌──── (reservado, ver §4.4)
        EXT2 ─┼→ [Mux Superior] ─→ [Acumulador] ──┤
     RF_OUT ──┤      sel_sup                     wr, clear
    SH_OUT ───┘                                   │
                                                  ▼  bus_acc [0;7]
                        ┌─────────────────────────┼───────────────────────┐
                        │                         │                       │
                        ▼                         ▼                       ▼
                [Register File]              [ALU] A=bus_acc         [Mux Inferior]
                 8 registros                  B=RF_OUT                sel_inf
                 addr(3), wr                  A2 A1 A0                    │
                        │                         │                       ▼
                        │                         ▼                  [Shifter]
                        │                    (salida ALU) ─────────→   sh
                        │                                                │
                        └──────→ RF_OUT ─────────────────────────────────┤
                                                                         ▼
                                             realimentación a Mux Superior (SH_OUT)

   bus_acc ──→ [Buffer de salida] en ──→ dato_out   (triángulo inferior izquierdo)
```

### 4.2 Funcionamiento de cada módulo (Etapa 1 — entregable 2)

| Módulo | Función | Señales |
|---|---|---|
| **Mux superior** | Selecciona qué dato carga el acumulador: entrada externa, salida del banco o realimentación del shifter | `sel_sup(2b)` |
| **Acumulador** | Registro de 8 bits que retiene operandos y resultados parciales | `wr` (carga), `clear` (limpia, prioridad sobre `wr`), `rst` |
| **Register File** | 8 registros de 8 bits; lectura combinacional en la dirección `addr`, escritura síncrona | `addr(3b)`, `wr`, entrada = `bus_acc` |
| **ALU** | 8 operaciones según la tabla oficial | `A2 A1 A0` |
| **Mux inferior** | Elige qué entra al shifter: resultado de la ALU o el propio acumulador | `sel_inf(1b)` |
| **Shifter** | Desplazamiento de bits; en los 4 experimentos actúa en **modo pasar** (es el camino obligatorio de realimentación) | `sh(2b)` |
| **Buffer de salida** | Triángulo inferior izquierdo: saca `bus_acc` al puerto `dato_out` cuando está habilitado | `en` |
| **Detector de cero** | Añadido y justificado: `cero = 1` cuando la salida del shifter es 0 | flag → control |

### 4.3 Cómo llegan los operandos y se reutiliza el resultado

- **Operando A de la ALU** = salida del acumulador (`bus_acc`).
- **Operando B de la ALU** = lectura combinacional del banco en `addr`.
- **Resultado** → mux inferior → shifter (pasar) → realimentación al mux
  superior → acumulador. **El shifter es parte obligatoria del camino de
  realimentación**, de ahí que todos los pasos que escriben un valor calculado
  usen `sel_sup = 11 (SH_OUT)`.
- `bus_acc` también alimenta: la entrada de datos del banco, el mux inferior y
  el buffer de salida (el acumulador "es el bus" de datos del datapath).
- **Restricción del banco**: un solo puerto `addr` ⇒ en cada microciclo se lee
  y se escribe **el mismo registro**; las tablas lo respetan.

### 4.4 Datos técnicos pendientes de confirmación (nombres simbólicos)

| # | Pendiente | Nombre/valor simbólico (provisional) |
|---|---|---|
| 1 | Códigos del mux superior | `sel_sup`: 00=EXT1, 01=EXT2 (reservado), 10=RF_OUT, 11=SH_OUT |
| 2 | Códigos del mux inferior | `sel_inf`: 0=salida ALU, 1=bus_acc |
| 3 | Comportamiento del shifter | `sh`: 00=**pasar** (imprescindible); 01=izq 1, 10=der lógico 1, 11=der aritmético 1 — *provisionales, solo se usa 00* |
| 4 | Sentido del buffer de salida | tri-estado con habilitación `en`; si es buffer simple, `en=1` siempre |
| 5 | Entrada EXT2 del mux superior | reservada, sin uso (atada a 0) |
| 6 | Flag de cero | no aparece en el diagrama; añadido sobre la salida del shifter con justificación |

Si el diagrama oficial difiere, se ajustan **constantes** en `control.vhd`; el
diseño no cambia.

---

## 5. Tabla de operaciones de la ALU (confirmada en la imagen)

| A2 | A1 | A0 | Operación | F |
|---|---|---|---|---|
| 0 | 0 | 0 | Pasar A | F = A (**no** es cero) |
| 0 | 0 | 1 | Suma | F = A + B |
| 0 | 1 | 0 | Resta | F = A − B |
| 0 | 1 | 1 | Incremento | F = A + 1 |
| 1 | 0 | 0 | Decremento | F = A − 1 |
| 1 | 0 | 1 | OR | F = A OR B |
| 1 | 1 | 0 | AND | F = A AND B |
| 1 | 1 | 1 | NOT | F = NOT A |

Aritmética módulo 256 (sin acarreo a la salida).

## 6. Tabla de señales de control (etapa 3 — entregable 4)

| Señal | Ancho | Dirección | Significado |
|---|---|---|---|
| `sel_sup` | 2 | control → mux superior | 00=EXT1, 01=EXT2, 10=RF_OUT, 11=SH_OUT |
| `wr_acc` | 1 | control → acumulador | carga en el flanco |
| `clr_acc` | 1 | control → acumulador | limpia (prioridad sobre `wr`) |
| `addr` | 3 | control → banco | dirección de lectura/escritura |
| `wr_rf` | 1 | control → banco | escribe `RF[addr] ← bus_acc` |
| `op_alu` | 3 | control → ALU | A2 A1 A0 |
| `sel_inf` | 1 | control → mux inferior | 0=ALU, 1=bus_acc |
| `sh` | 2 | control → shifter | 00=pasar (usado siempre) |
| `out_en` | 1 | control → buffer | habilita `dato_out` |
| `cero` | 1 | datapath → control | salida del shifter == 0 |
| `fin` | 1 | control → tb | fin del algoritmo |
| `paso` | 7 | control → tb | dirección de microcódigo activa |
| `ciclos` | 16 | control → tb | microciclos ejecutados hasta `fin` |

**Modelo temporal:** FSM síncrona, **un microciclo por flanco de subida**. Las
salidas de control son combinacionales a partir de `paso`; los registros del
datapath (acumulador y banco) capturan en ese mismo flanco. El flag `cero` se
calcula sobre la **salida del shifter** (el valor que se va a escribir en el
acumulador), de modo que un salto condicional puede ir en la **misma
microinstrucción** que produce el resultado (sin ciclos de espera).

---

## 7. Etapa 2 — Diseño de los algoritmos

### 7.1 Asignación de variables a los 8 registros (entregable 6)

| Reg | Exp 1 (suma) | Exp 2 (n!) | Exp 3 (A×B) | Exp 4 (Fib) |
|---|---|---|---|---|
| R0 | — | — | — | — |
| R1 | i (contador ↓) | i (factor actual ↑) | — | n (contador ↓) |
| R2 | s (suma parcial) | fact | — | a = F(k−2) |
| R3 | — | X del producto | A | b = F(k−1) |
| R4 | — | Y del producto | B | next |
| R5 | — | veces = n−1 | — | — |
| R6 | — | P (producto) | P (producto) | — |
| R7 | — | — | — | — |

### 7.2 Pseudocódigos (entregable 5)

**Exp 1 — Suma (n ≥ 1)**
```
R1 ← n ; R2 ← 0                     # i = n, s = 0
bucle:
  if (R2 + R1) ...                   # no se necesita: se resta el contador
  Acc ← R2 ; Acc ← Acc + R1 ; R2 ← Acc      # s = s + i
  Acc ← R1 ; Acc ← Acc − 1                 # i = i − 1
  si cero → fin (salta)                     # i llegó a 0
  R1 ← Acc ; ir a bucle
fin: Acc ← R2                           # S(n) = s
```

**Exp 2 — Factorial (1 ≤ n ≤ 5)**
```
fact ← 1 ; R5 ← n − 1 ; i ← 2
si R5 = 0 → fin                        # n = 1 ⇒ 1! = 1
bucle:
  P ← mult(fact, i)                    # multiplicación por sumas repetidas
  fact ← P ; i ← i + 1
  R5 ← R5 − 1 ; si cero → fin
  ir a bucle
fin: Acc ← fact
```
```
mult(X, Y):                            # R3 ← X, R4 ← Y, R6 ← 0
  bucle_m: R6 ← R6 + R3 ; Y ← Y − 1
           si Y ≠ 0 → bucle_m
  devuelve R6                          # suma Y veces X
```

**Exp 3 — Multiplicación (0 ≤ A,B ≤ 15)**
```
R3 ← A ; R4 ← B ; R6 ← 0
si B = 0 → fin (P = 0)
bucle_m: R6 ← R6 + R3 ; R4 ← R4 − 1 ; si R4 ≠ 0 → bucle_m
fin: Acc ← R6
```

**Exp 4 — Fibonacci (0 ≤ n ≤ 13, F(0)=0, F(1)=1)**
```
a ← 0 ; b ← 1 ; n ← entrada
si n = 0 → fin_a                            # F(0) = a
si n = 1 → fin_b                            # F(1) = b
veces ← n − 1
bucle: next ← a + b ; a ← b ; b ← next
        veces ← veces − 1 ; si cero → fin_b # n−1 iteraciones
        ir a bucle
fin_a: Acc ← a                              # F(0)
fin_b: Acc ← b                              # F(n)
```

Verificación de convención: con a=0, b=1, k iteraciones dejan b = F(k+1),
por eso el bucle corre n−1 veces. n=1 sale en fin_b con b=1 = F(1) ✓;
n=7 ⇒ 6 iteraciones ⇒ b=13 = F(7) ✓.

### 7.3 Operaciones ALU usadas por experimento

| Experimento | 001 A+B | 010 A−B | 011 A+1 | 100 A−1 |
|---|---|---|---|---|
| Exp 1 | s+i | — (flag inicial no usado) | — | i−1 |
| Exp 2 | R6+X | 0−R5 (¿n=1?) | i+1 | Y−1, veces−1 |
| Exp 3 | R6+R3 | 0−R4 (¿B=0?) | — | Y−1 |
| Exp 4 | a+b | 0−R1 (¿n=0?) | — | n−1 |

La resta `0 − X` sólo se usa como **detector de cero** (da 0 sólo si X=0).

---

## 8. Etapa 3 — Tablas de microoperaciones (entregable 7)

Columnas: **paso · operación · fuente · ALU · muxes · wr/clear/addr · destino ·
resultado**. El paso es la **dirección absoluta de la ROM de microcódigo**
(`paso = modo × 32 + micropaso`; `modo`: 00=exp1, 01=exp2, 10=exp3, 11=exp4).

Leyenda: SS=`sel_sup`, SI=`sel_inf`, `—` = no aplica.

### 8.1 Exp 1 — Suma de 1..n (ROM 0–10, modo 00)

| Paso | Operación | Fuente | ALU | Muxes | wr/clear/addr | Destino | Resultado |
|---|---|---|---|---|---|---|---|
| 0 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 1 | Acc←n | EXT1 | — | SS=00 | wr_acc | Acc | n |
| 2 | R1←Acc | — | — | — | wr_rf, addr=1 | R1 | i = n |
| 3 | Acc←0 | — | — | SS=00 | clear | Acc | s = 0 |
| 4 | Acc←s | R2 | — | SS=10 | wr_acc, addr=2 | Acc | s |
| 5 | Acc←s+i | R1 | 001 A+B | SS=11, SI=0, sh=00 | wr_acc, addr=1 | Acc | s+i |
| 6 | R2←Acc | — | — | — | wr_rf, addr=2 | R2 | s nuevo |
| 7 | Acc←i | R1 | — | SS=10 | wr_acc, addr=1 | Acc | i |
| 8 | Acc←i−1 | Acc | 100 A−1 | SS=11, SI=0, sh=00 | wr_acc | Acc | i−1; **si cero → paso 10** |
| 9 | R1←Acc | — | — | — | wr_rf, addr=1; **salta → 4** | R1 | i nuevo |
| 10 | Acc←s | R2 | — | SS=10 | wr_acc, out_en | Acc | **S(n)** (fin) |

n=5: s = 5,9,12,14,15 ⇒ 15 ✓. Exige **n ≥ 1** (documentado).

### 8.2 Exp 2 — Factorial (ROM 32–63, modo 01)

| Paso | Operación | Fuente | ALU | Muxes | wr/clear/addr | Destino | Resultado |
|---|---|---|---|---|---|---|---|
| 32 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 33 | Acc←1 | EXT1 | — | SS=00 | wr_acc | Acc | 1 |
| 34 | R2←Acc | — | — | — | wr_rf, addr=2 | R2 | fact = 1 |
| 35 | Acc←n | EXT1 | — | SS=00 | wr_acc | Acc | n |
| 36 | Acc←n−1 | Acc | 100 A−1 | SS=11, SI=0 | wr_acc | Acc | n−1 |
| 37 | R5←Acc | — | — | — | wr_rf, addr=5 | R5 | veces = n−1 |
| 38 | Acc←2 | EXT1 | — | SS=00 | wr_acc | Acc | 2 |
| 39 | R1←Acc | — | — | — | wr_rf, addr=1 | R1 | i = 2 |
| 40 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 41 | Acc←0−R5 | 0, R5 | 010 A−B | SS=11, SI=0 | wr_acc, addr=5 | Acc | 0 si R5=0; **si cero → paso 63** |
| 42 | Acc←R2 | R2 | — | SS=10 | wr_acc, addr=2 | Acc | X = fact |
| 43 | R3←Acc | — | — | — | wr_rf, addr=3 | R3 | X |
| 44 | Acc←R1 | R1 | — | SS=10 | wr_acc, addr=1 | Acc | Y = i |
| 45 | R4←Acc | — | — | — | wr_rf, addr=4 | R4 | Y |
| 46 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 47 | R6←Acc | — | — | — | wr_rf, addr=6 | R6 | P = 0 |
| 48 | Acc←P | R6 | — | SS=10 | wr_acc, addr=6 | Acc | P |
| 49 | Acc←P+X | R3 | 001 A+B | SS=11, SI=0 | wr_acc, addr=3 | Acc | P+X |
| 50 | R6←Acc | — | — | — | wr_rf, addr=6 | R6 | P nuevo |
| 51 | Acc←Y | R4 | — | SS=10 | wr_acc, addr=4 | Acc | Y |
| 52 | Acc←Y−1 | Acc | 100 A−1 | SS=11, SI=0 | wr_acc | Acc | Y−1; **si cero → paso 55** |
| 53 | R4←Acc | — | — | — | wr_rf, addr=4; **salta → 48** | R4 | Y nuevo |
| 54 | salto | — | — | — | **salta → 48** | — | bucle multiplicación |
| 55 | Acc←P | R6 | — | SS=10 | wr_acc, addr=6 | Acc | producto |
| 56 | R2←Acc | — | — | — | wr_rf, addr=2 | R2 | fact = P |
| 57 | Acc←i | R1 | — | SS=10 | wr_acc, addr=1 | Acc | i |
| 58 | Acc←i+1 | Acc | 011 A+1 | SS=11, SI=0 | wr_acc | Acc | i+1 |
| 59 | R1←Acc | — | — | — | wr_rf, addr=1 | R1 | i nuevo |
| 60 | Acc←veces | R5 | — | SS=10 | wr_acc, addr=5 | Acc | R5 |
| 61 | Acc←veces−1 | Acc | 100 A−1 | SS=11, SI=0 | wr_acc | Acc | R5−1; **si cero → paso 63** |
| 62 | R5←Acc | — | — | — | wr_rf, addr=5; **salta → 42** | R5 | veces nueva |
| 63 | Acc←fact | R2 | — | SS=10 | wr_acc, out_en | Acc | **n!** (fin) |

n=5 ⇒ 1×2=2, ×3=6, ×4=24, ×5=120 ✓. n=1 ⇒ salta en 41 ⇒ 1 ✓.

### 8.3 Exp 3 — Multiplicación A×B (ROM 64–78, modo 10)

| Paso | Operación | Fuente | ALU | Muxes | wr/clear/addr | Destino | Resultado |
|---|---|---|---|---|---|---|---|
| 64 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 65 | Acc←A | EXT1 | — | SS=00 | wr_acc | Acc | A |
| 66 | R3←Acc | — | — | — | wr_rf, addr=3 | R3 | A |
| 67 | Acc←B | EXT1 | — | SS=00 | wr_acc | Acc | B |
| 68 | R4←Acc | — | — | — | wr_rf, addr=4 | R4 | B |
| 69 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 70 | R6←Acc | — | — | — | wr_rf, addr=6 | R6 | P = 0 |
| 71 | Acc←0−R4 | 0, R4 | 010 A−B | SS=11, SI=0 | wr_acc, addr=4 | Acc | 0 si B=0; **si cero → paso 78** |
| 72 | Acc←P | R6 | — | SS=10 | wr_acc, addr=6 | Acc | P |
| 73 | Acc←P+A | R3 | 001 A+B | SS=11, SI=0 | wr_acc, addr=3 | Acc | P+A |
| 74 | R6←Acc | — | — | — | wr_rf, addr=6 | R6 | P nuevo |
| 75 | Acc←B′ | R4 | — | SS=10 | wr_acc, addr=4 | Acc | B′ |
| 76 | Acc←B′−1 | Acc | 100 A−1 | SS=11, SI=0 | wr_acc | Acc | B′−1; **si cero → paso 78** |
| 77 | R4←Acc | — | — | — | wr_rf, addr=4; **salta → 72** | R4 | B′ nuevo |
| 78 | Acc←P | R6 | — | SS=10 | wr_acc, out_en | Acc | **A×B** (fin) |

4×3 ⇒ 4,8,12 ✓. B=0 ⇒ paso 71 → fin con P=0 ✓.

### 8.4 Exp 4 — Fibonacci (ROM 96–118, modo 11)

> Corrección detectada en la simulación: con a=0, b=1, **k iteraciones dejan
> b = F(k+1)**; por eso el bucle se ejecuta **n−1 veces** (n = 0 y n = 1 salen
> antes del bucle).

| Paso | Operación | Fuente | ALU | Muxes | wr/clear/addr | Destino | Resultado |
|---|---|---|---|---|---|---|---|
| 96 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 97 | R2←Acc | — | — | — | wr_rf, addr=2 | R2 | a = 0 |
| 98 | Acc←1 | EXT1 | — | SS=00 | wr_acc | Acc | 1 |
| 99 | R3←Acc | — | — | — | wr_rf, addr=3 | R3 | b = 1 |
| 100 | Acc←n | EXT1 | — | SS=00 | wr_acc | Acc | n |
| 101 | R1←Acc | — | — | — | wr_rf, addr=1 | R1 | n |
| 102 | Acc←0 | — | — | SS=00 | clear | Acc | 0 |
| 103 | Acc←0−R1 | 0, R1 | 010 A−B | SS=11, SI=0 | wr_acc, addr=1 | Acc | 0 si n=0; **si cero → paso 117** |
| 104 | Acc←n | R1 | — | SS=10 | wr_acc, addr=1 | Acc | n |
| 105 | Acc←n−1 | Acc | 100 A−1 | SS=11, SI=0 | wr_acc | Acc | n−1; **si cero → paso 118** (n=1) |
| 106 | R1←Acc | — | — | — | wr_rf, addr=1 | R1 | veces = n−1 |
| 107 | Acc←a | R2 | — | SS=10 | wr_acc, addr=2 | Acc | a |
| 108 | Acc←a+b | R3 | 001 A+B | SS=11, SI=0 | wr_acc, addr=3 | Acc | next |
| 109 | R4←Acc | — | — | — | wr_rf, addr=4 | R4 | next |
| 110 | Acc←b | R3 | — | SS=10 | wr_acc, addr=3 | Acc | b |
| 111 | R2←Acc | — | — | — | wr_rf, addr=2 | R2 | a′ = b |
| 112 | Acc←next | R4 | — | SS=10 | wr_acc, addr=4 | Acc | next |
| 113 | R3←Acc | — | — | — | wr_rf, addr=3 | R3 | b′ = next |
| 114 | Acc←R1 | R1 | — | SS=10 | wr_acc, addr=1 | Acc | contador |
| 115 | Acc←cnt−1 | Acc | 100 A−1 | SS=11, SI=0 | wr_acc | Acc | cnt−1; **si cero → paso 118** |
| 116 | R1←Acc | — | — | — | wr_rf, addr=1; **salta → 107** | R1 | contador nuevo |
| 117 | Acc←a | R2 | — | SS=10 | wr_acc, out_en | Acc | **F(0)** (fin) |
| 118 | Acc←b | R3 | — | SS=10 | wr_acc, out_en | Acc | **F(n)** (fin) |

n=0 ⇒ paso 103 → 117 ⇒ 0 ✓. n=1 ⇒ paso 105 → 118 ⇒ 1 ✓.
n=7 ⇒ bucle de 6 iteraciones ⇒ 13 ✓.

### 8.5 Señales de entrada externa (`EXT1`) por paso

El testbench presenta el dato externo en la dirección de microcódigo donde
`sel_sup = 00`:

| Experimento | Paso con EXT1 | Valor |
|---|---|---|
| Exp 1 | 1 | n |
| Exp 2 | 33 | 1 |
| Exp 2 | 35 | n |
| Exp 2 | 38 | 2 |
| Exp 3 | 65 | A |
| Exp 3 | 67 | B |
| Exp 4 | 98 | 1 |
| Exp 4 | 100 | n |

---

## 9. Diseño de la unidad de control (entregable 8)

`control.vhd`: **FSM secuencial** implementada como

- registro `paso` (7 bits) = dirección de la ROM de microinstrucciones
  (base = `modo × 32`);
- ROM con **una microinstrucción por paso** (`sel_sup, wr_acc, clr_acc, addr,
  wr_rf, op_alu, sel_inf, sh, out_en, salta, salto_si_cero, dir, fin`);
- en cada flanco de subida: si `fin=0`, `paso ← dir` (si `salta` o
  `salto_si_cero ∧ cero`) o `paso ← paso+1`; `ciclos ← ciclos+1`;
  si `fin=1`, se detiene;
- `cero` (del datapath) decide los saltos; `modo` elige el algoritmo y debe
  mantenerse estable durante la ejecución.

Esto equivale a una FSM de estado = micropaso, con las tablas de la §8 como
**programa** de la unidad de control (la tabla de microoperaciones es literal
el contenido de la ROM).

## 10. Etapa 4 — Implementación (entregable 9)

```
vhdl/datapath-3/
  src/
    alu.vhd              8 operaciones (tabla §5), combinacional
    acumulador.vhd       8 b, wr/clear/rst (clear con prioridad)
    banco_registros.vhd  8×8 b, lectura combinacional, escritura síncrona
    mux_superior.vhd     4 entradas, sel_sup(2b)
    mux_inferior.vhd     2 entradas, sel_inf(1b)
    shifter.vhd          4 códigos (00=pasar); códigos 01/10/11 provisionales
    detector_cero.vhd    salida del shifter == 0 → flag
    buffer_salida.vhd    tri-estado con en → dato_out
    datapath.vhd         integra los 8 anteriores (estructural)
    control.vhd          FSM + ROM de microinstrucciones (§8)
  tb/
    tb_alu, tb_acumulador, tb_banco_registros, tb_mux_superior,
    tb_mux_inferior, tb_shifter, tb_detector_cero, tb_buffer_salida,
    tb_datapath (micro-ops manuales), tb_control (secuencia de la FSM),
    tb_exp1_suma, tb_exp2_factorial, tb_exp3_mult, tb_exp4_fibonacci
```

Convenciones (`vhdl/AGENTS.md`): VHDL-2008 conservador (GHDL 4.1 y 6.0), un
fichero = una entidad, `snake_case`, `numeric_std`, comentarios en español,
cabecera breve, `assert … severity failure` + `report "… OK"` en cada tb, sin
bucles infinitos de simulación.

Los tbs de aplicación instancian **`datapath` + `control` directamente** (sin
módulo extra) y exponen en el `.vcd`: `clk, rst, modo, paso, ciclos, fin,
acc_q, rf_dout, cero, dato_out`.

## 11. Etapa 5 — Validación experimental (entregable 10)

| tb | Casos | Esperado | Comprobación |
|---|---|---|---|
| `tb_alu` | (a=5,b=3) en las 8 ops | 5,8,2,6,4,7,1,250 | assert por op; 000 ⇒ 5 ≠ 0 |
| `tb_acumulador` | clear, carga, retención | — | assert de `q` |
| `tb_banco_registros` | reset, escrito R0/R7, lectura | 0 en todos tras rst | assert |
| `tb_mux_superior` / `tb_mux_inferior` | todos los `sel` | — | assert |
| `tb_shifter` | 4 códigos | 00 = idéntico | assert (01/10/11 provisionales) |
| `tb_detector_cero` | 0, 1, 255 | 1, 0, 0 | assert |
| `tb_buffer_salida` | en=1/0 | dato / 'Z' | assert |
| `tb_datapath` | micro-ops manuales del Exp 1 (n=5) | intermedios: 5,5,4,9… | assert paso a paso |
| `tb_control` | los 4 modos con cero=0 y cero=1 | secuencia exacta de `paso` (§8) y `fin`; sin `fin` en 100 ciclos con cero=0 | assert |
| `tb_exp1_suma` | n = 1, 3, 5 | 1, 6, 15 | assert en `acc_q` al `fin` |
| `tb_exp2_factorial` | n = 1, 5 | 1, 120 | assert |
| `tb_exp3_mult` | 4×3, 5×5, 15×15 | 12, 25, 225 | assert |
| `tb_exp4_fibonacci` | n = 0, 1, 7, 13 | 0, 1, 13, 233 | assert |

Cada tb reporta el número de **microciclos** (`ciclos`) al terminar: fuente de
la tabla de tiempos del reporte.

Workflow de capturas (idéntico a `mapeo-memoria`):
`scripts/vhdl-sim datapath-3 tb_exp1_suma` → `scripts/vhdl-wave
vhdl/datapath-3/salidas/tb_exp1_suma.vcd` → PNG en
`reportes/datapath-3/figuras/` (para la sección 4 del reporte, fase posterior).

## 12. Flujo Git (una feature = una rama, PR → `dev`)

| # | Rama | Contenido |
|---|---|---|
| 1 | `docs/plan-datapath-3` | este plan + imágenes en `docs/imagenes-datapath-3/` |
| 2 | `vhdl/datapath-3/modulos-basicos` | 8 módulos pequeños + sus tbs |
| 3 | `vhdl/datapath-3/datapath-integrado` | `datapath.vhd` + `tb_datapath` |
| 4 | `vhdl/datapath-3/unidad-control` | `control.vhd` (ROM §8) + `tb_control` |
| 5 | `vhdl/datapath-3/exp1-suma` | `tb_exp1_suma` |
| 6 | `vhdl/datapath-3/exp2-factorial` | `tb_exp2_factorial` |
| 7 | `vhdl/datapath-3/exp3-multiplicacion` | `tb_exp3_mult` |
| 8 | `vhdl/datapath-3/exp4-fibonacci` | `tb_exp4_fibonacci` |

Commits en español, Conventional Commits:
`vhdl(datapath-3): añadir la ALU con su testbench autochequeado`.

## 13. Verificación (en cada rama)

```bash
# desde la raíz del repo
scripts/vhdl-analizar datapath-3
scripts/vhdl-sim datapath-3 tb_alu            # y cada tb nuevo
scripts/vhdl-wave vhdl/datapath-3/salidas/tb_alu.vcd
```

Checklist de cierre (espejo del PR template):

- [ ] Rama con una sola feature; commits en español (Conventional Commits).
- [ ] Sin artefactos en el diff (`.vcd`, `.cf`, `.ghdl/`, `salidas/`).
- [ ] `scripts/vhdl-analizar datapath-3` correcto.
- [ ] Todos los `tb_*.vhd` pasan `scripts/vhdl-sim` (lo repite el CI).
- [ ] Cada tb termina con `report "… OK"` y falla con `assert` si hay error.

## 14. Riesgos y limitaciones

- **GHDL mcode**: solo simulación; no se promete síntesis.
- **Portabilidad GHDL 4.1/6.0**: VHDL-2008 conservador; el CI (Ubuntu) prueba
  la 4.x, localmente la 6.0.
- **Sin flag de acarreo**: desbordamientos silenciosos → límites de la §3.
- **Detector de cero añadido**: única ampliación respecto al diagrama, con
  justificación (fin de bucles). Queda señalada para ratificar.
- **Shifter**: sólo se usa el modo pasar; los demás códigos son provisionales.
- **`modo` estable** durante la ejecución; `EXT2` sin usar.
- Si el diagrama oficial cambia algún código de mux/shifter, se ajustan
  constantes en `control.vhd` sin rediseñar.
