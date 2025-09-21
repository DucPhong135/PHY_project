# Parallel 32-bit LFSR scrambler generator for PCIe Gen3 polynomial
# Polynomial: x^23 + x^21 + x^16 + x^8 + x^5 + x^2 + 1
# LFSR width = 23 bits, Output width = 32 bits
# Output: Verilog-ready assign statements

def lfsr_step(state, poly):
    """Advance LFSR one step (state as sets of indices)."""
    feedback = set()
    for t in poly:
        feedback ^= state[t]  # XOR = symmetric difference
    return [feedback] + state[:-1]

def generate_parallel_scrambler(poly, lfsr_width, word_width):
    # initialize state: S[i] = {i}
    state = [{i} for i in range(lfsr_width)]
    outputs = []

    for _ in range(word_width):
        # PCIe scrambler XORs input bit with MSB of state
        outputs.append(state[-1])
        state = lfsr_step(state, poly)

    return outputs, state

def format_assign_out(i, taps):
    taps_str = " ^ ".join(f"STATE[{t}]" for t in sorted(taps))
    if taps_str:
        return f"assign D_OUT_NEXT[{i}] = D_IN[{i}] ^ {taps_str};"
    else:
        return f"assign D_OUT_NEXT[{i}] = D_IN[{i}];"

def format_assign_state(i, taps):
    taps_str = " ^ ".join(f"STATE[{t}]" for t in sorted(taps))
    if taps_str:
        return f"assign STATE_NEXT[{i}] = {taps_str};"
    else:
        return f"assign STATE_NEXT[{i}] = 1'b0;"

if __name__ == "__main__":
    # PCIe Gen3 polynomial taps (0-based, LFSR[22] is MSB)
    poly = [0, 2, 5, 8, 16, 21, 22]
    lfsr_width = 23
    word_width = 32

    outs, next_state = generate_parallel_scrambler(poly, lfsr_width, word_width)

    print("// Scrambled output equations")
    for i, taps in enumerate(outs):
        print(format_assign_out(i, taps))

    print("\n// Next LFSR state after 32 bits")
    for i, taps in enumerate(next_state):
        print(format_assign_state(i, taps))
