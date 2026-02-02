# RISC-V RV32I SoC with RSA Accelerator

## 1. Tổng quan hệ thống

Hệ thống SoC này được thiết kế xoay quanh **lõi RISC-V RV32I** tối giản, kết hợp với **khối tăng tốc phần cứng RSA** nhằm phục vụ các tác vụ mật mã bất đối xứng. Mục tiêu của thiết kế là:

* Dễ hiểu, dễ mở rộng cho mục đích học tập và nghiên cứu
* Phân tách rõ ràng giữa **khối xử lý tổng quát (CPU)** và **khối tăng tốc chuyên dụng (RSA)**
* Phù hợp để triển khai trên FPGA hoặc mô phỏng RTL

Kiến trúc tổng thể tuân theo mô hình SoC cổ điển:

```
+----------------------+
|      RV32I Core      |
|  (Instruction CPU)  |
+----------+-----------+
           |
   Internal Bus / IF
           |
+----------v-----------+
|   RSA Accelerator    |
| (Modular Exponent)  |
+----------------------+
```

---

## 2. Cấu trúc thư mục và các file chính

### 2.1. `RV32I_core.v`

Đây là **lõi CPU RISC-V RV32I**, chịu trách nhiệm:

* Fetch – Decode – Execute tập lệnh RV32I
* Điều khiển luồng chương trình
* Giao tiếp với các module ngoại vi thông qua tín hiệu điều khiển

**Đặc điểm chính**:

* ISA: RV32I (không bao gồm M-extension)
* Thiết kế hướng RTL rõ ràng, phù hợp cho học kiến trúc máy tính
* Dễ tích hợp thêm coprocessor hoặc accelerator

---

### 2.2. `processor.v`

File này đóng vai trò **top-level processor wrapper**, kết nối:

* RV32I core
* Bộ nhớ / bus nội bộ
* Khối RSA

Chức năng chính:

* Điều phối tín hiệu giữa CPU và RSA
* Định tuyến dữ liệu và tín hiệu điều khiển
* Đóng vai trò trung gian giữa phần mềm (chạy trên CPU) và phần cứng tăng tốc

Có thể xem `processor.v` như **bộ xương sống của SoC**.

---

### 2.3. `rsa.v`

Đây là **khối tăng tốc RSA phần cứng**, thực hiện các phép toán mật mã tốn tài nguyên tính toán:

[
C = M^e \bmod N
]

**Thành phần chính**:

* Bộ nhân modulo
* Bộ lũy thừa modulo (Modular Exponentiation)
* FSM điều khiển các bước tính toán

**Vai trò trong SoC**:

* Giảm tải cho CPU khi thực hiện RSA
* Tăng tốc đáng kể so với việc tính toán hoàn toàn bằng phần mềm

---

## 3. Kiến trúc hệ thống (SoC Architecture)

### 3.1. Phân tách chức năng

| Khối              | Vai trò                                  |
| ----------------- | ---------------------------------------- |
| RV32I Core        | Điều khiển, chạy firmware, quản lý luồng |
| RSA Accelerator   | Thực hiện phép toán mật mã nặng          |
| Processor Wrapper | Kết nối và điều phối các module          |

Thiết kế này tuân theo triết lý **hardware/software co-design**:

* Phần mềm quyết định *khi nào* dùng RSA
* Phần cứng quyết định *làm thế nào* để tính nhanh nhất

---

## 4. Nguyên lý hoạt động tổng thể

### 4.1. Luồng thực thi

1. CPU RV32I fetch và execute chương trình
2. Khi cần mã hóa/giải mã RSA:

   * CPU ghi dữ liệu (M, e, N) vào thanh ghi của RSA
3. CPU kích hoạt tín hiệu `start`
4. Khối RSA:

   * Thực hiện modular exponentiation
   * Chạy FSM nội bộ cho đến khi hoàn tất
5. RSA trả về kết quả và bật cờ `done`
6. CPU đọc kết quả và tiếp tục chương trình

---

### 4.2. Vai trò của phần cứng tăng tốc

Nếu không có RSA accelerator:

* CPU phải thực hiện nhiều vòng lặp nhân và modulo
* Rất chậm với số bit lớn

Với RSA accelerator:

* Phép toán được song song hóa ở mức phần cứng
* Thời gian xử lý giảm mạnh
* CPU chỉ đóng vai trò điều phối

---

## 5. Điểm nổi bật của SoC

* ✅ Thiết kế **module hóa**, dễ mở rộng
* ✅ Kết hợp **RISC-V + Crypto Accelerator** thực tế
* ✅ Phù hợp cho:

  * Đồ án kiến trúc máy tính
  * Nghiên cứu tăng tốc mật mã
  * FPGA prototyping

---

## 6. Hướng mở rộng trong tương lai

* Thêm bus chuẩn (AXI-lite / Wishbone)
* Hỗ trợ RV32IM (M-extension)
* Tăng tốc thêm AES / SHA
* Tối ưu RSA bằng Montgomery Multiplication

---

## 7. Kết luận

SoC này minh họa rõ ràng cách xây dựng một hệ thống hoàn chỉnh:

> **CPU tổng quát + Accelerator chuyên dụng = Hiệu năng cao & thiết kế gọn gàng**

Đây là nền tảng rất tốt để tiếp tục phát triển các SoC phục vụ bảo mật và nhúng.

---


# RSA với Montgomery Reduction – Giải thích hoạt động & Interface Verilog

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

