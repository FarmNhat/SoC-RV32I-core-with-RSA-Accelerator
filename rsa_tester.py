# ==============================
# RSA Montgomery - Minimal MAIN
# ==============================

WIDTH = 64


def montgomery_reduce(T, N, N_INV, R, WIDTH):
    mask = R - 1
    m = ((T & mask) * N_INV) & mask
    t = (T + m * N) >> WIDTH
    if t >= N:
        t -= N
    return t


def montgomery_mul(A, B, N, N_INV, R, WIDTH):
    return montgomery_reduce(A * B, N, N_INV, R, WIDTH)


def rsa_mod_exp(M, E, N, WIDTH):
    R = 1 << WIDTH

    # -N^{-1} mod R
    N_INV = (-pow(N, -1, R)) % R

    # R^2 mod N
    R2_MOD_N = (R * R) % N

    # Convert to Montgomery domain
    M_bar   = montgomery_mul(M, R2_MOD_N, N, N_INV, R, WIDTH)
    res_bar = montgomery_mul(1, R2_MOD_N, N, N_INV, R, WIDTH)

    # Square & multiply
    for i in reversed(range(E.bit_length())):
        res_bar = montgomery_mul(res_bar, res_bar, N, N_INV, R, WIDTH)
        if (E >> i) & 1:
            res_bar = montgomery_mul(res_bar, M_bar, N, N_INV, R, WIDTH)

    # Convert back
    C = montgomery_mul(res_bar, 1, N, N_INV, R, WIDTH)

    return N_INV, R2_MOD_N, C


if __name__ == "__main__":
    # ===== INPUT =====
    s = "phong"

    M = 0
    for ch in s:
        M = (M << 8) | ord(ch)

    E = 4
    N = 11

    N_INV, R2_MOD_N, C = rsa_mod_exp(M, E, N, WIDTH)

    # ===== OUTPUT =====
    print("\n===== RSA Montgomery Result =====")
    print(f"M        = {M}")
    print(f"E        = {E}")
    print(f"N        = {N}")
    print(f"N_INV    = {N_INV}")
    print(f"R2_MOD_N = {R2_MOD_N}")
    print(f"C        = {C}")
