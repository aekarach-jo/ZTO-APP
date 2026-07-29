# คำขอเพิ่ม Bill No. / Payment No. ใน Order & Payment API

**ผู้ขอ:** ทีม Mobile (ZTO_APP)
**วันที่:** 2026-07-29
**สถานะ:** รอ backend implement

---

## 1. ปัญหา / สิ่งที่ต้องการ

หน้า **Payment successful** ในแอป ตอนนี้แสดงได้แค่ ยอดเงิน กับข้อความ "Payment successful"
เพราะ API ไม่ได้ส่ง **เลขที่บิล** กลับมาเลย

ผู้ใช้ไม่มีเลขอ้างอิงไว้แจ้งแอดมิน / ตรวจสอบย้อนหลัง

ในระบบหลังบ้าน (หน้า Payment) มีเลขนี้อยู่แล้ว 2 ตัว:

| คอลัมน์ในหลังบ้าน | ตัวอย่าง |
|---|---|
| Bill No. | `2607-00020` |
| Payment No. | `SK2607-00002` |

**ต้องการให้ส่งเลข 2 ตัวนี้กลับมาใน API response** เพื่อแสดงในแอป

---

## 2. Endpoint ที่ขอให้แก้

### 2.1 `POST /orders/pickup` (และ `POST /orders/forward`)

Response ปัจจุบันที่แอป parse:

```json
{
  "success": true,
  "data": {
    "id": "...",
    "type": "pickup",
    "paymentStatus": "pending",
    "amount": 10000,
    "currency": "LAK",
    "weight": 1.5,
    "recipientName": "rolan",
    "items": [
      { "laravelParcelId": "123", "price": 0, "shippingFee": 10000, "itemTotal": 10000 }
    ]
  }
}
```

**ขอเพิ่ม:**

```json
{
  "success": true,
  "data": {
    "id": "...",
    "billNo": "2607-00020",      // 👈 เพิ่ม
    "type": "pickup",
    "paymentStatus": "pending",
    "amount": 10000,
    "...": "ฟิลด์เดิมทั้งหมดคงไว้"
  }
}
```

---

### 2.2 `POST /orders/{orderId}/pay`

Response ปัจจุบันที่แอป parse:

```json
{
  "success": true,
  "data": {
    "transactionRef": "...",
    "method": "onepay",
    "qrString": "00020101...",
    "paymentUrl": null
  }
}
```

**ขอเพิ่ม:**

```json
{
  "success": true,
  "data": {
    "transactionRef": "...",
    "billNo": "2607-00020",         // 👈 เพิ่ม
    "paymentNo": "SK2607-00002",    // 👈 เพิ่ม
    "method": "onepay",
    "qrString": "00020101...",
    "paymentUrl": null
  }
}
```

> **คำถามถึง backend:** `transactionRef` ที่ส่งอยู่ตอนนี้ คือค่าเดียวกับ `Payment No.` (`SK2607-00002`) หรือเป็น ref ของ OnePay คนละตัว?
> - ถ้า **เป็นค่าเดียวกัน** → ไม่ต้องเพิ่ม `paymentNo` แค่ยืนยันกลับมาก็พอ
> - ถ้า **คนละตัว** → ขอให้เพิ่ม `paymentNo` แยกตามด้านบน

---

### 2.3 `GET /orders/{orderId}/payment-status` (สำคัญที่สุด)

แอปเรียก endpoint นี้ทุก 3 วินาที ระหว่างรอผู้ใช้สแกน QR
**เมื่อ `isPaid: true` แอปจะเด้งไปหน้า Payment successful ทันที** ดังนั้นเลขบิลต้องมากับ response นี้

Response ปัจจุบันที่แอป parse:

```json
{
  "success": true,
  "data": {
    "isPaid": true,
    "bankRef": "...",
    "paidAt": "2026-07-29T19:16:52Z"
  }
}
```

**ขอเพิ่ม:**

```json
{
  "success": true,
  "data": {
    "isPaid": true,
    "billNo": "2607-00020",         // 👈 เพิ่ม
    "paymentNo": "SK2607-00002",    // 👈 เพิ่ม
    "amount": 10000,                // 👈 เพิ่ม (ยอดที่ชำระจริง ไว้ยืนยันตรงกับที่แอปแสดง)
    "bankRef": "...",
    "paidAt": "2026-07-29T19:16:52Z"
  }
}
```

---

## 3. สรุปฟิลด์ที่ขอ

| ฟิลด์ | ชนิด | ตัวอย่าง | Endpoint ที่ขอ | หมายเหตุ |
|---|---|---|---|---|
| `billNo` | `string` | `"2607-00020"` | pickup / forward, pay, payment-status | เลขที่บิล |
| `paymentNo` | `string` | `"SK2607-00002"` | pay, payment-status | เลขที่การชำระ (อาจซ้ำกับ `transactionRef`) |
| `amount` | `int` | `10000` | payment-status | ยอดที่ชำระจริง (LAK, ไม่มีทศนิยม) |

---

## 4. ข้อกำหนด (ขอให้ทำตามนี้)

1. **ชื่อฟิลด์เป็น camelCase** ให้ตรงกับ response เดิม (`paymentStatus`, `transactionRef`, `paidAt`) ไม่ใช่ `bill_no`
2. **ส่งเป็น string เสมอ** ไม่ต้อง strip เลข 0 นำหน้า เก็บ format `YYYYMM-NNNNN` ตามที่แสดงในหลังบ้าน
3. **ห้ามลบ / เปลี่ยนชื่อฟิลด์เดิม** — เพิ่มฟิลด์ใหม่เข้าไปเท่านั้น (แอปเวอร์ชันเก่าที่อยู่ในมือผู้ใช้จะยังทำงานได้ปกติ)
4. ถ้าบางกรณียังไม่มีเลขบิล ให้ส่ง `null` ได้ (แอปจะซ่อนแถวนั้น) แต่ **ตอน `isPaid: true` ควรมีค่าเสมอ**
5. ยังคงห่อด้วย envelope `{ "success": true, "data": {...} }` แบบเดิม

---

## 5. ผลลัพธ์ฝั่งแอปหลังได้ฟิลด์นี้

หน้า Payment successful จะแสดงเพิ่ม:

```
        ✓
  Payment successful
Your payment has been confirmed
       ₭10,000

──────────────────────────
Bill No.        2607-00020
Payment No.   SK2607-00002
Date     2026-07-29 19:16
──────────────────────────
        [ Done ]
```

(พร้อมปุ่มกดคัดลอกเลขบิล)

---

## 6. ติดต่อกลับ

รบกวนยืนยันกลับ 2 ข้อ:
1. `transactionRef` = `Payment No.` หรือไม่
2. เพิ่ม `billNo` ใน `payment-status` ได้เลยไหม (จุดนี้จำเป็นที่สุด)
