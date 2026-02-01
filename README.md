# RSA với Montgomery Reduction – Giải thích hoạt động & Interface Verilog

Tài liệu này mô tả:
- Nguyên lý RSA
- Montgomery multiplication & reduction
- Ý nghĩa các tham số `R`, `N_INV`, `R2_MOD_N`
- Input / Output của các module Verilog
- Luồng hoạt động của module `rsa`

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

### 3.1 Cách chuẩn bị ngoài module


R          = 2^WIDTH
N_INV      = -N^{-1} mod R
R2_MOD_N   = (R * R) mod N
⚠️ Các giá trị này phải tính trước bằng phần mềm (Python/C)

4. Module montgomery_reduce
4.1 Chức năng
Thực hiện:

result = T × R⁻¹ mod N
4.2 Interface
module montgomery_reduce #(
    parameter WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,

    input  wire [2*WIDTH-1:0]     T,      // T < N*R
    input  wire [WIDTH-1:0]       N,      // modulus
    input  wire [WIDTH-1:0]       N_INV,  // -N^{-1} mod R

    output reg  [WIDTH-1:0]       result,
    output reg                    done
);
4.3 Thuật toán phần cứng
m = (T mod R) × N_INV mod R
t = (T + m×N) / R
if t ≥ N → result = t − N
else      result = t
4.4 FSM nội bộ
State	Chức năng
IDLE	Chờ start
CALC_M	Tính m
CALC_T	Tính t và xuất kết quả
5. Module montgomery_mul
5.1 Chức năng
Tính:

result = A × B × R⁻¹ mod N
5.2 Interface
module montgomery_mul #(
    parameter WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,

    input  wire [WIDTH-1:0]       A,
    input  wire [WIDTH-1:0]       B,
    input  wire [WIDTH-1:0]       N,
    input  wire [WIDTH-1:0]       N_INV,

    output wire [WIDTH-1:0]       result,
    output wire                   done
);
5.3 Hoạt động
Nhân thường:

T = A × B
Gọi montgomery_reduce(T)

6. Module rsa
6.1 Chức năng
Thực hiện:

C = M^E mod N
bằng square-and-multiply trong miền Montgomery

6.2 Interface
module rsa #(
    parameter WIDTH = 32,
    parameter E_BITS = 32
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,

    input  wire [WIDTH-1:0]       M,
    input  wire [E_BITS-1:0]      E,
    input  wire [WIDTH-1:0]       N,
    input  wire [WIDTH-1:0]       N_INV,
    input  wire [WIDTH-1:0]       R2_MOD_N,

    output reg  [WIDTH-1:0]       C,
    output reg                    done
);
7. Luồng hoạt động RSA
7.1 Chuyển sang miền Montgomery
M̄ = Mont(M × R² mod N)
1̄ = Mont(1 × R² mod N)
7.2 Square & Multiply
Với từng bit của E từ MSB → LSB:

res = res × res
if E[i] == 1:
    res = res × M̄
(Tất cả đều là Montgomery multiply)

7.3 Chuyển về miền thường
C = Mont(res × 1)
8. FSM module RSA
State	Ý nghĩa
IDLE	Chờ start
CONV_M	Đưa M vào Montgomery
CONV_R	Khởi tạo result
LOOP_START	Bắt đầu vòng lặp
SQUARE_WAIT	Chờ bình phương
MULT_WAIT	Chờ nhân
REDUCE_START	Thoát Montgomery
REDUCE_WAIT	Xuất kết quả
9. Lưu ý quan trọng
N bắt buộc là số lẻ

mont_start chỉ được bật 1 chu kỳ

FSM phải đợi mont_done

Không được giữ start = 1 liên tục → sẽ bị loop vô hạn

10. Tóm tắt
Thành phần	Vai trò
montgomery_reduce	Core modulo
montgomery_mul	Nhân modulo
rsa	Điều khiển exponentiation
N, N_INV, R2_MOD_N	Chuẩn bị ngoài module
