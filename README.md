# RSA với Montgomery Reduction – Giải thích hoạt động & Interface Verilog

---

## 1. Tổng quan RSA

RSA tính:

C = M^E mod N


Trong đó:
- `M` : plaintext (message)
- `E` : public exponent
- `N` : modulus (`N = p × q`, **số lẻ**)
- `C` : ciphertext

Trong phần cứng, phép `mod N` với số lớn rất tốn tài nguyên → dùng **Montgomery arithmetic** để tránh chia.

---

## 2. Montgomery Arithmetic

### 2.1 Định nghĩa

Chọn:
R = 2^k (k = WIDTH)
gcd(R, N) = 1


Định nghĩa dạng Montgomery:
x̄ = x × R mod N


Montgomery reduction tính:
Mont(T) = T × R⁻¹ mod N


với điều kiện:
T < N × R


---

## 3. Ý nghĩa các tham số

| Tên | Ý nghĩa |
|----|--------|
| `R` | `2^WIDTH` |
| `N` | Modulus RSA (số lẻ) |
| `N_INV` | `-N⁻¹ mod R` |
| `R2_MOD_N` | `R² mod N` |

---
### 4. Lưu ý quan trọng

- N bắt buộc là số lẻ

- mont_start chỉ được bật 1 chu kỳ

- FSM phải đợi mont_done

- Không được giữ start = 1 liên tục → sẽ bị loop vô hạn

### 5. Sử dụng
- Input một chuỗi M

- Output là cipher text

- Các số cần chuẩn bị sẵn (có thể nạp sẵn vào bộ nhớ nếu triển khai SoC): N, N_INV, R2_MOD_N, Các số này được tính toán 1 lần ở phần mềm sau đó sử dụng cho mọi Input

- Các giá trị sau phải tính trước bằng phần mềm (Python/C): 

R          = 2^WIDTH

N_INV      = -N^{-1} mod R

R2_MOD_N   = (R * R) mod N

