# FPGA-Based Lightweight Cryptography using PRESENT-80 - Group 1


This project implements a lightweight cryptography system on an FPGA board using the **PRESENT-80 block cipher**. The design is written in **Verilog HDL**, simulated using **ModelSim**, synthesized and implemented using **Gowin EDA Education**, and tested on the **Gowin ACG525 / GW5A-LV25UG324C2/I1 FPGA board** through UART communication.

The FPGA receives plaintext and key data from a PC, encrypts the data using the PRESENT-80 hardware core, and sends the ciphertext back to the PC through UART.

---

## Project Overview

PRESENT-80 is a lightweight block cipher designed for resource-constrained devices such as RFID, IoT devices, embedded systems, and low-power hardware platforms.

In this project:

* Plaintext size: **64 bits**
* Key size: **80 bits**
* Ciphertext size: **64 bits**
* Communication interface: **UART**
* FPGA board: **Gowin ACG525**
* FPGA device: **GW5A-LV25UG324C2/I1**
* UART baud rate: **115200**
* Verification method: **ModelSim simulation + Python golden model + real FPGA board test**

---

## Repository Structure

```text
.
├── rtl/
│   ├── present80_encrypt.v
│   ├── uart_rx.v
│   ├── uart_tx.v
│   ├── lwc_uart_top_ascii.v
│   └── lwc_uart_top_debug.v
│
├── sim/
│   ├── tb_present80_encrypt.v
│   ├── tb_lwc_uart_top.v
│   ├── run_present80.do
│   └── run_uart_top.do
│
├── constraints/
│   ├── acg525_lwc.cst
│   └── acg525_lwc.sdc
│
├── golden_model/
│   └── present80_golden.py
│
├── scripts/
│   └── host_send_present80.py
│
└── README.md
```

---

## Hardware Used

| Component         | Description             |
| ----------------- | ----------------------- |
| FPGA Board        | Gowin ACG525            |
| FPGA Device       | GW5A-LV25UG324C2/I1     |
| Clock             | 50 MHz                  |
| UART Interface    | CH9102 USB-UART         |
| Programming Tool  | Gowin Programmer / JTAG |
| Terminal Software | RealTerm or Tera Term   |

---

## Software Used

| Software             | Purpose                                        |
| -------------------- | ---------------------------------------------- |
| Gowin EDA Education  | Synthesis, Place & Route, Bitstream generation |
| ModelSim             | Verilog simulation                             |
| Python               | Golden model verification                      |
| RealTerm / Tera Term | UART communication with FPGA                   |

---

## System Architecture

```text
PC / RealTerm
     |
     | UART
     |
FPGA Top Module
     |
     +-- UART Receiver
     |
     +-- Command Parser
     |
     +-- PRESENT-80 Encryption Core
     |
     +-- UART Transmitter
```

The PC sends plaintext and key data to the FPGA through UART.
The FPGA parses the command, performs PRESENT-80 encryption, and returns the ciphertext.

---

## UART Protocol

UART configuration:

```text
Baud rate: 115200
Data bits: 8
Parity: None
Stop bits: 1
Flow control: None
```

### Self-Test Command

Send:

```text
T
```

Expected response:

```text
CT=5579C1387B228445
```

This command uses the default PRESENT-80 test vector:

```text
Plaintext = 0000000000000000
Key       = 00000000000000000000
Ciphertext = 5579C1387B228445
```

### Custom Encryption Command

Send:

```text
E <plaintext_16_hex> <key_20_hex>
```

Example:

```text
E 0000000000000000 00000000000000000000
```

Expected response:

```text
CT=5579C1387B228445
```

Another example:

```text
E DEADBEEFCAFEBABE 00112233445566778899
```

Expected response:

```text
CT=02A7002C724248E1
```

---

## Python Golden Model

A Python golden model is included to verify the FPGA output.

The golden model simulates the PRESENT-80 algorithm independently from the Verilog design. It is used to generate the expected ciphertext for each plaintext/key pair.

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

Example with custom input:

```powershell
py present80_golden.py DEADBEEFCAFEBABE 00112233445566778899
```

Expected output:

```text
CT=02A7002C724248E1
```

---

## ModelSim Simulation

The `sim/` folder contains ModelSim testbenches and `.do` scripts.

### Simulate PRESENT-80 Core

Open ModelSim, change directory to the `sim/` folder, then run:

```tcl
do run_present80.do
```

This test checks the PRESENT-80 encryption core using the standard test vector:

```text
Plaintext = 0000000000000000
Key       = 00000000000000000000
Expected  = 5579C1387B228445
```

### Simulate UART Top-Level System

Run:

```tcl
do run_uart_top.do
```

This simulation verifies the UART receiver, command parser, PRESENT-80 core, and UART transmitter together.

---

## Gowin EDA Build Steps

1. Open Gowin EDA Education.
2. Create a new Verilog project.
3. Select device:

```text
GW5A-LV25UG324C2/I1
```

4. Add all Verilog files from the `rtl/` folder.
5. Set the top module:

```text
lwc_uart_top_debug
```

or:

```text
lwc_uart_top_ascii
```

6. Add constraint files:

```text
constraints/acg525_lwc.cst
constraints/acg525_lwc.sdc
```

7. Run:

```text
Synthesis
Place & Route
Generate Bitstream
Program Device
```

8. Open RealTerm or Tera Term and test through UART.

---

## Constraint Files

### Physical Constraint File

The `.cst` file maps Verilog signals to real FPGA pins on the ACG525 board.

Example mappings:

| Signal           | Function           |
| ---------------- | ------------------ |
| `clk`            | 50 MHz board clock |
| `uart_tx`        | UART transmit      |
| `uart_rx`        | UART receive       |
| `key0` / `rst_n` | Reset              |
| `led[3:0]`       | Status LEDs        |

### Timing Constraint File

The `.sdc` file defines the main system clock timing requirement.

The board clock is 50 MHz:

```text
Clock frequency = 50 MHz
Clock period    = 20 ns
```

This allows Gowin EDA to check whether the design can operate correctly at the required frequency.

---

## Verification Results

| Test | Plaintext          | Key                    | Expected Ciphertext | FPGA Output        | Result        |
| ---: | ------------------ | ---------------------- | ------------------- | ------------------ | ------------- |
|    1 | `0000000000000000` | `00000000000000000000` | `5579C1387B228445`  | `5579C1387B228445` | PASS          |
|    2 | `FFFFFFFFFFFFFFFF` | `00000000000000000000` | `A112FFC72F68417B`  | `A112FFC72F68417B` | PASS          |
|    3 | `0000000000000000` | `FFFFFFFFFFFFFFFFFFFF` | `E72C46C0F5945049`  | `E72C46C0F5945049` | PASS          |
|    4 | `FFFFFFFFFFFFFFFF` | `FFFFFFFFFFFFFFFFFFFF` | `3333DCD3213210D2`  | `3333DCD3213210D2` | PASS          |


---

## Example RealTerm Output

After programming the FPGA and pressing reset:

```text
READY
```

Send:

```text
T
```

Expected response:

```text
CT=5579C1387B228445
```
---

## Project Status

Current status:

* PRESENT-80 encryption core implemented
* UART communication working
* Python golden model working
* ModelSim simulation available
* FPGA board test successful
* RealTerm output verified with known test vector

---

## Limitations

This project currently supports only encryption. It does not yet include:

* PRESENT-80 decryption
* PRESENT-128
* CBC / CTR / OFB / CFB modes
* Multi-block file encryption
* Power consumption measurement
* Side-channel attack protection

---

## Future Work

Possible future improvements:

* Add PRESENT-80 decryption
* Add PRESENT-128 support
* Add CBC or CTR mode
* Automate UART testing from Python
* Display ciphertext on OLED or seven-segment LEDs
* Compare FPGA resource usage with AES or Ascon
* Measure power consumption
* Optimize area or throughput

---

## References

[1] A. Bogdanov et al., “PRESENT: An Ultra-Lightweight Block Cipher,” CHES 2007.

[2] NIST SP 800-232, “Ascon-Based Lightweight Cryptography Standards for Constrained Devices.”

[3] Hardware Implementations of NIST Lightweight Cryptographic Candidates on FPGA

[4] Gowin Semiconductor, “GW5A Series of FPGA Products Data Sheet.” 

[5] Xiaomeige / Gowin, “ACG525 GPIO Pin Table.”


---

## Author

Created by:

```text
TT.Minh aka ardashie cung thanh vien nhom 1
```

For FPGA Programming coursework.
