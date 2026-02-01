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

### 4. Module montgomery_reduce
- Thực hiện: result = T × R⁻¹ mod N

- Thuật toán phần cứng:

  m = (T mod R) × N_INV mod R
  
  t = (T + m×N) / R
  
  if t ≥ N → result = t − N
  
  else      result = t
  
  FSM nội bộ
  
  State	Chức năng
  
  IDLE	Chờ start
  
  CALC_M	Tính m
  
  CALC_T	Tính t và xuất kết quả

---
### 5. Module montgomery_mul


- Tính: result = A × B × R⁻¹ mod N
- Hoạt động: T = A × B

### 6. Module rsa
- Thực hiện: C = M^E mod N bằng square-and-multiply trong miền Montgomery


- Chuyển sang miền Montgomery
  
  M̄ = Mont(M × R² mod N)
  
  1̄ = Mont(1 × R² mod N)

- Square & Multiply với từng bit của E từ MSB → LSB:

  res = res × res
  
  if E[i] == 1:
  
  res = res × M̄
  
  (Montgomery multiply)
  
  Chuyển về miền thường
  
  C = Mont(res × 1)

- FSM module RSA:

  State	Ý nghĩa
  
  IDLE	Chờ start
  
  CONV_M	Đưa M vào Montgomery
  
  CONV_R	Khởi tạo result
  
  LOOP_START	Bắt đầu vòng lặp
  
  SQUARE_WAIT	Chờ bình phương
  
  MULT_WAIT	Chờ nhân
  
  REDUCE_START	Thoát Montgomery
  
  REDUCE_WAIT	Xuất kết quả

---
### 7. Lưu ý quan trọng

- N bắt buộc là số lẻ

- mont_start chỉ được bật 1 chu kỳ

- FSM phải đợi mont_done

- Không được giữ start = 1 liên tục → sẽ bị loop vô hạn

### 8. Sử dụng
- Input một chuỗi M

- Output là cipher text

- Các số cần chuẩn bị sẵn (có thể nạp sẵn vào bộ nhớ nếu triển khai SoC): N, N_INV, R2_MOD_N, Các số này được tính toán 1 lần ở phần mềm sau đó sử dụng cho mọi Input

- Các giá trị sau phải tính trước bằng phần mềm (Python/C): 

R          = 2^WIDTH

N_INV      = -N^{-1} mod R

R2_MOD_N   = (R * R) mod N

