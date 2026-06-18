# FPGA-Based Lightweight Cryptography using PRESENT-80 on Gowin ACG525 - Group 1

* Top module: `lwc_uart_top_debug`
* Algorithm: PRESENT-80 Lightweight Block Cipher
* Board: Gowin ACG525
* FPGA: GW5A-LV25UG324C2/I1
* Communication: UART 115200 baud
* Verification: ModelSim, Python Golden Model, RealTerm board test

---

## Mục lục

* `present80_encrypt`
* `uart_rx`
* `uart_tx`
* `lwc_uart_top_debug`
* `lwc_uart_top_ascii`
* `present80_golden.py`
* ModelSim Simulation
* Gowin EDA Implementation
* UART Testing
* Verification Results

---

## Project Overview

This project implements a lightweight cryptography system on FPGA using the PRESENT-80 block cipher. The FPGA receives plaintext and key data from a PC through UART, encrypts the data using the PRESENT-80 hardware core, and sends the ciphertext back to the PC.

The project is verified using:

* Python Golden Model
* ModelSim simulation
* RealTerm UART testing on the physical FPGA board

---

## System Block Diagram

```text
PC / RealTerm
     |
     | UART 115200 8N1
     |
FPGA Top Module
     |
     +-- UART Receiver
     +-- Command Parser
     +-- PRESENT-80 Encryption Core
     +-- UART Transmitter
```

---

## `present80_encrypt`

File: `present80_encrypt.v`

This module implements the PRESENT-80 encryption core.

| Signal       | Direction | Width | Description         |
| ------------ | --------- | ----: | ------------------- |
| `clk`        | input     |     1 | System clock        |
| `rst_n`      | input     |     1 | Active-low reset    |
| `start`      | input     |     1 | Start encryption    |
| `plaintext`  | input     |    64 | 64-bit plaintext    |
| `key`        | input     |    80 | 80-bit key          |
| `ciphertext` | output    |    64 | 64-bit ciphertext   |
| `done`       | output    |     1 | Encryption finished |

---

## `uart_rx`

File: `uart_rx.v`

This module receives serial UART data from the PC.

| Signal       | Direction | Width | Description                        |
| ------------ | --------- | ----: | ---------------------------------- |
| `clk`        | input     |     1 | System clock                       |
| `rst_n`      | input     |     1 | Active-low reset                   |
| `rx`         | input     |     1 | UART RX input                      |
| `data_out`   | output    |     8 | Received byte                      |
| `data_valid` | output    |     1 | One-clock pulse when byte is ready |

---

## `uart_tx`

File: `uart_tx.v`

This module transmits UART data from the FPGA to the PC.

| Signal     | Direction | Width | Description                   |
| ---------- | --------- | ----: | ----------------------------- |
| `clk`      | input     |     1 | System clock                  |
| `rst_n`    | input     |     1 | Active-low reset              |
| `tx_start` | input     |     1 | Start transmitting one byte   |
| `tx_data`  | input     |     8 | Byte to transmit              |
| `tx`       | output    |     1 | UART TX output                |
| `tx_busy`  | output    |     1 | High when transmitter is busy |

---

## `lwc_uart_top_debug`

File: `lwc_uart_top_debug.v`

This is the top-level module used for board testing.

| Signal    | Direction | Width | Description                |
| --------- | --------- | ----: | -------------------------- |
| `clk`     | input     |     1 | 50 MHz board clock         |
| `rst_n`   | input     |     1 | Active-low reset from KEY0 |
| `uart_rx` | input     |     1 | UART data from PC          |
| `uart_tx` | output    |     1 | UART data to PC            |
| `led`     | output    |     4 | Status LEDs                |

### Supported UART Commands

Self-test command:

```text
T
```

Expected output:

```text
CT=5579C1387B228445
```

Custom encryption command:

```text
E <plaintext_16_hex> <key_20_hex>
```

Example:

```text
E DEADBEEFCAFEBABE 00112233445566778899
```

Expected output:

```text
CT=02A7002C724248E1
```

---

## Python Golden Model

File: `golden_model/present80_golden.py`

The golden model is used to generate the expected ciphertext independently from the Verilog design.

Run:

```powershell
py present80_golden.py 0000000000000000 00000000000000000000
```

Expected output:

```text
PT=0000000000000000
K =00000000000000000000
CT=5579C1387B228445
```

---

## ModelSim Simulation

The `sim/` folder contains testbenches and `.do` scripts.

Run PRESENT-80 core simulation:

```tcl
do run_present80.do
```

Run UART top-level simulation:

```tcl
do run_uart_top.do
```

---

## Gowin EDA Implementation

Device:

```text
GW5A-LV25UG324C2/I1
```

Main steps:

```text
Synthesis
Place & Route
Generate Bitstream
Program Device
```

Constraint files:

```text
constraints/acg525_lwc.cst
constraints/acg525_lwc.sdc
```

---

## UART Configuration

| Parameter    | Value  |
| ------------ | ------ |
| Baud rate    | 115200 |
| Data bits    | 8      |
| Parity       | None   |
| Stop bits    | 1      |
| Flow control | None   |

Recommended terminal software:

* RealTerm
* Tera Term

---

## Verification Results

| Test | Plaintext          | Key                    | Expected Ciphertext | FPGA Output        | Result        |
| ---: | ------------------ | ---------------------- | ------------------- | ------------------ | ------------- |
|    1 | `0000000000000000` | `00000000000000000000` | `5579C1387B228445`  | `5579C1387B228445` | PASS          |
|    2 | `FFFFFFFFFFFFFFFF` | `00000000000000000000` | `A112FFC72F68417B`  | `A112FFC72F68417B` | PASS          |
|    3 | `0000000000000000` | `FFFFFFFFFFFFFFFFFFFF` | `E72C46C0F5945049`  | `E72C46C0F5945049` | PASS          |
|    4 | `FFFFFFFFFFFFFFFF` | `FFFFFFFFFFFFFFFFFFFF` | `3333DCD3213210D2`  | `3333DCD3213210D2` | PASS          |

---


## Project Status

* PRESENT-80 encryption core: completed
* UART communication: completed
* Python golden model: completed
* ModelSim simulation: completed
* Physical FPGA board test: completed
* Report and verification table: in progress

---

## References

[1] A. Bogdanov et al., “PRESENT: An Ultra-Lightweight Block Cipher,” CHES 2007.

[2] NIST SP 800-232, “Ascon-Based Lightweight Cryptography Standards for Constrained Devices.”

[3] Hardware Implementations of NIST Lightweight Cryptographic Candidates on FPGA

[4] Gowin Semiconductor, “GW5A Series of FPGA Products Data Sheet.” 

[5] Xiaomeige / Gowin, “ACG525 GPIO Pin Table.”

---

## Author

```text
TT.Minh va group 1
```

FPGA Programming Course Project.
