# FPGA-Based Lightweight Cryptography using PRESENT-80 on Gowin ACG525 - Group 1

* Top module: `lwc_uart_top_debug`
* Algorithm: PRESENT-80 Lightweight Block Cipher
* Board: Gowin ACG525
* FPGA: GW5A-LV25UG324C2/I1
* Communication: UART 115200 baud
* Verification: ModelSim, Python Golden Model, RealTerm board test

---

## Catalogue

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

<img width="1201" height="674" alt="{9F6F5153-8E1C-471B-849D-9DBA9E601003}" src="https://github.com/user-attachments/assets/b47ef1a4-b4f0-4923-a62a-6f0ab14a1970" />


## Verification Flow

<img width="1197" height="674" alt="{6F7B0B98-AB28-4E9C-BC7A-76680BC2B1FC}" src="https://github.com/user-attachments/assets/1282c6c3-cd03-42af-ab06-b938923c7c54" />


## UART Processing Flow

<img width="1197" height="615" alt="{1DF485EA-DBB7-481A-84BA-F396AA475AC4}" src="https://github.com/user-attachments/assets/db9e1b0f-8c72-4615-9d82-4f84b087977e" />


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
## Why Are `T` and `E` Commands Used?

UART only transfers a stream of bytes. It does not automatically know whether the received bytes represent a plaintext, an encryption key, a test request, or another type of data.

Therefore, this project defines a simple **application-level UART command protocol**. The first character tells the FPGA how the remaining data should be interpreted.

| Command | Meaning | Description                                                  |
| ------- | ------- | ------------------------------------------------------------ |
| `T`     | Test    | Runs a built-in PRESENT-80 test vector                       |
| `E`     | Encrypt | Encrypts a user-provided plaintext using a user-provided key |

### Self-Test Command: `T`

The command:

```text
T
```

instructs the FPGA to run a predefined test using:

```text
Plaintext = 0000000000000000
Key       = 00000000000000000000
```

The expected response is:

```text
CT=5579C1387B228445
```

This command is useful for quickly checking whether:

* the FPGA has been programmed correctly;
* the UART connection is working;
* the PRESENT-80 core produces the correct known ciphertext;
* the UART transmitter can return the result to the PC.

No plaintext or key needs to be entered manually because both values are already stored in the self-test logic.

---

### Custom Encryption Command: `E`

The general encryption command is:

```text
E <plaintext> <key>
```

For example:

```text
E 0000000000000000 00000000000000000000
```

The fields have the following meanings:

| Field     |                    Length | Meaning                          |
| --------- | ------------------------: | -------------------------------- |
| `E`       |               1 character | Requests an encryption operation |
| Plaintext | 16 hexadecimal characters | 64-bit input block               |
| Key       | 20 hexadecimal characters | 80-bit encryption key            |

The space characters are used as separators so that the command is easier for a person to read. They do not form part of the plaintext or key.

After receiving the complete command, the FPGA:

1. detects the `E` command;
2. receives the 16-character plaintext;
3. receives the 20-character key;
4. converts the ASCII hexadecimal characters into binary values;
5. starts the PRESENT-80 encryption core;
6. converts the 64-bit ciphertext back into hexadecimal text;
7. sends the result through UART.

Example response:

```text
CT=5579C1387B228445
```

---

## Why Are Hexadecimal Characters Used?

The plaintext, key, and ciphertext are represented in **hexadecimal notation**.

Hexadecimal uses these sixteen symbols:

```text
0 1 2 3 4 5 6 7 8 9 A B C D E F
```

Each hexadecimal character represents exactly four binary bits:

| Hexadecimal | Binary |
| ----------- | ------ |
| `0`         | `0000` |
| `1`         | `0001` |
| `9`         | `1001` |
| `A`         | `1010` |
| `B`         | `1011` |
| `F`         | `1111` |

Therefore:

```text
16 hexadecimal characters × 4 bits = 64-bit plaintext
20 hexadecimal characters × 4 bits = 80-bit key
16 hexadecimal characters × 4 bits = 64-bit ciphertext
```

For example:

```text
Plaintext = DEADBEEFCAFEBABE
Key       = 00112233445566778899
```

is sent as:

```text
E DEADBEEFCAFEBABE 00112233445566778899
```

The FPGA returns the corresponding ciphertext in the same readable hexadecimal format:

```text
CT=02A7002C724248E1
```

---

## Why Use ASCII Instead of Raw Binary Data?

The UART interface uses ASCII hexadecimal text rather than raw binary bytes because ASCII is easier to:

* enter manually using RealTerm or Tera Term;
* read and verify on the screen;
* include in screenshots and demonstrations;
* compare with the Python golden model;
* debug when communication errors occur;
* use without special handling for bytes such as `0x00`.

For example, the ASCII command:

```text
E 0000000000000000 00000000000000000000
```

is easier to understand than the equivalent raw binary packet:

```text
45 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

ASCII communication requires more transmitted bytes and is less efficient than a binary protocol. However, this project prioritizes clarity, debugging, and demonstration rather than maximum communication speed.

---

## UART Commands and Python Commands Are Different

Commands beginning with:

```powershell
py present80_golden.py
```

are executed on the PC and are **not sent to the FPGA**.

For example:

```powershell
py present80_golden.py 0000000000000000 00000000000000000000
```

runs the Python golden model and calculates the expected ciphertext on the computer.

The command:

```text
E 0000000000000000 00000000000000000000
```

is sent through UART to the FPGA and calculates the actual ciphertext using the hardware implementation.

The two results are then compared:

```text
Python Golden Model CT = 5579C1387B228445
FPGA Hardware CT       = 5579C1387B228445
Result                 = PASS
```

This comparison verifies that the FPGA implementation behaves correctly.

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

[1] K. McKay, L. Bassham, M. S. Turan, and N. Mouha, “Report on
lightweight cryptography,” National Institute of Standards and Technol-
ogy, Tech. Rep. NISTIR 8114, 2017.
[2] A. Bogdanov, L. R. Knudsen, G. Leander, C. Paar, A. Poschmann,
M. J. B. Robshaw, Y. Seurin, and C. Vikkelsoe, “PRESENT: An ultra-
lightweight block cipher,” in Cryptographic Hardware and Embedded
Systems – CHES 2007, ser. Lecture Notes in Computer Science, vol.
4727. Springer, 2007, pp. 450–466.
[3] International Organization for Standardization, “Information security—
lightweight cryptography—part 2: Block ciphers,” ISO/IEC, Tech. Rep.
ISO/IEC 29192-2:2019, 2019.
[4] M. S. Turan, K. McKay, J. Kang, J. Kelsey, and D. Chang, “Ascon-based
lightweight cryptography standards for constrained devices: Authenticated
encryption, hash, and extendable output functions,” National Institute of
Standards and Technology, Tech. Rep. NIST Special Publication 800-232,
2025.
[5] S. Kerckhof, F. Durvaux, C. Hocquet, D. Bol, and F.-X. Standaert,
“Towards green cryptography: A comparison of lightweight ciphers
from the energy viewpoint,” in Cryptographic Hardware and Embedded
Systems – CHES 2012, ser. Lecture Notes in Computer Science, vol. 7428.
Springer, 2012, pp. 390–407.
[6] A. Y. Poschmann, “Lightweight cryptography: Cryptographic engineering
for a pervasive world,” Ph.D. dissertation, Ruhr-University Bochum, 2009,
iACR Cryptology ePrint Archive, Report 2009/516.
[7] S. Kolay and D. Mukhopadhyay, “Khudra: A new lightweight block
cipher for FPGAs,” in Security, Privacy, and Applied Cryptography En-
gineering, ser. Lecture Notes in Computer Science, vol. 8804. Springer,
2014, pp. 126–145.
[8] Gowin Semiconductor Corporation, GW5A Series of FPGA Products Data
Sheet, Gowin Semiconductor Corporation, 2025.
[9] Xiaomeige FPGA Team, Pin Information Table of the ACG525 Gowin
FPGA Development Board, Wuhan Xinluheng Technology, 2025, board
pin-assignment document supplied with the development kit.

---

## Author

```text
TT.Minh va group 1
```

FPGA Programming Course Project.
