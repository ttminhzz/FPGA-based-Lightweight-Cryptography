import sys

SBOX = [
    0xC, 0x5, 0x6, 0xB,
    0x9, 0x0, 0xA, 0xD,
    0x3, 0xE, 0xF, 0x8,
    0x4, 0x7, 0x1, 0x2
]

def sbox_layer(state: int) -> int:
    out = 0
    for i in range(16):
        nibble = (state >> (4 * i)) & 0xF
        out |= SBOX[nibble] << (4 * i)
    return out

def p_layer(state: int) -> int:
    out = 0
    for i in range(63):
        bit = (state >> i) & 1
        out |= bit << ((16 * i) % 63)

    bit63 = (state >> 63) & 1
    out |= bit63 << 63
    return out

def update_key_80(key: int, round_counter: int) -> int:
    key &= (1 << 80) - 1

    key = ((key << 61) & ((1 << 80) - 1)) | (key >> 19)

    top_nibble = (key >> 76) & 0xF
    key &= ~(0xF << 76)
    key |= SBOX[top_nibble] << 76

    key ^= (round_counter & 0x1F) << 15

    return key

def present80_encrypt(plaintext: int, key: int) -> int:
    state = plaintext & ((1 << 64) - 1)
    key_reg = key & ((1 << 80) - 1)

    for round_counter in range(1, 32):
        round_key = key_reg >> 16
        state ^= round_key
        state = sbox_layer(state)
        state = p_layer(state)
        key_reg = update_key_80(key_reg, round_counter)

    final_round_key = key_reg >> 16
    state ^= final_round_key

    return state

def clean_hex(s: str) -> str:
    return s.replace(" ", "").replace("_", "").replace("0x", "").replace("0X", "")

def main():
    if len(sys.argv) != 3:
        print("Usage:")
        print("  python present80_golden.py <plaintext_16_hex> <key_20_hex>")
        print()
        print("Example:")
        print("  python present80_golden.py 0000000000000000 00000000000000000000")
        return

    pt_hex = clean_hex(sys.argv[1])
    key_hex = clean_hex(sys.argv[2])

    if len(pt_hex) != 16:
        raise ValueError("Plaintext must be 16 hex characters = 64 bits")

    if len(key_hex) != 20:
        raise ValueError("Key must be 20 hex characters = 80 bits")

    plaintext = int(pt_hex, 16)
    key = int(key_hex, 16)

    ciphertext = present80_encrypt(plaintext, key)

    print(f"PT={plaintext:016X}")
    print(f"K ={key:020X}")
    print(f"CT={ciphertext:016X}")

if __name__ == "__main__":
    main()