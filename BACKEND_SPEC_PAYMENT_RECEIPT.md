# Spec สำหรับ Backend (NestJS): ข้อมูลใบเสร็จ + Barcode หน้า Payment Success

**ผู้ขอ:** ทีม Mobile (ZTO_APP / Flutter)
**วันที่:** 2026-07-30
**Base URL:** `http://14.207.141.82/api/v1`
**สถานะฝั่งแอป:** ทำเสร็จแล้ว รอ backend ส่ง field มาเท่านั้น

> เอกสารนี้แทน `API_REQUEST_BILL_NO.md` (ฉบับก่อน) — ใช้ฉบับนี้เป็นหลัก

---

## 1. หน้าจอที่ต้องใช้ข้อมูล

หลังผู้ใช้สแกน QR จ่ายเงินสำเร็จ แอปจะเด้งเข้าหน้า **ใบเสร็จ** ที่:
- แสดง **barcode (Code128)** ของ **Bill No.** เต็มความกว้างด้านบน → ให้แอดมินสแกนรับพัสดุ
- แสดงข้อมูลใบเสร็จ: Tracking No. / Bill No. / Payment No. / ยอดเงิน / วันที่ / เวลา
- **บันทึกรูปทั้งใบเสร็จลงคลังรูปอัตโนมัติ**

```
┌─────────────────────────────┐
│ ▌▌║▌║▌▌║▌║▌║▌▌║▌║▌▌║▌║▌▌║  │ ← barcode ของ billNo  ⭐ ต้องใช้ field นี้
│        2607-00020           │
│  แสดงบาร์โค้ดนี้ให้พนักงาน      │
│ - - - - - - - - - - - - - - │
│    ✓  Payment successful    │
│         ₭10,000             │ ← amount
│ - - - - - - - - - - - - - - │
│ Tracking No.    ZTO12345678 │ ← แอปมีอยู่แล้ว (จาก parcel)
│ Bill No.         2607-00020 │ ⭐ ต้องการ
│ Payment No.   SK2607-00002  │ ⭐ ต้องการ
│ Payment method    BCEL ONE  │
│ Date              30/07/2026│ ← จาก paidAt
│ Time                  19:16 │ ← จาก paidAt
└─────────────────────────────┘
```

**ปัญหาปัจจุบัน:** ทั้ง 3 endpoint ที่แอปเรียก ไม่มี field เลขบิลเลย
barcode จึงต้อง fallback ไปใช้ `order.id` ซึ่ง **ไม่ตรงกับเลขบิลในระบบหลังบ้าน** → แอดมินสแกนแล้วหาไม่เจอ

เลขที่ต้องการ มีอยู่แล้วในหน้า Payment ของ back office:

| คอลัมน์ | ตัวอย่าง |
|---|---|
| Bill No. | `2607-00020` |
| Payment No. | `SK2607-00002` |

---

## 2. Endpoint ที่ต้องแก้ (3 ตัว)

### 2.1 `POST /orders/pickup` — สร้าง order (pickup)

Request (ที่แอปส่งอยู่แล้ว):
```json
{ "parcelIds": [1024, 1025] }
```

Response ที่ต้องการ:
```json
{
  "success": true,
  "data": {
    "id": "ord_01J...",
    "billNo": "2607-00020",        // ⭐ เพิ่ม
    "type": "pickup",
    "paymentStatus": "pending",
    "amount": 10000,
    "currency": "LAK",
    "weight": 1.5,
    "recipientName": "rolan",
    "items": [
      { "laravelParcelId": "1024", "price": 0, "shippingFee": 10000, "itemTotal": 10000 }
    ]
  }
}
```

NestJS DTO:
```ts
export class OrderResponseDto {
  id: string;
  billNo: string | null;   // ⭐ เพิ่ม — เลขบิลของ order นี้
  type: 'pickup' | 'forward';
  paymentStatus: 'pending' | 'paid' | 'failed';
  amount: number;
  currency: string;
  weight?: number | null;
  recipientName?: string | null;
  items: OrderItemDto[];
}
```

> `POST /orders/forward` ใช้ response แบบเดียวกัน → เพิ่ม `billNo` ด้วย

---

### 2.2 `POST /orders/:orderId/pay` — เริ่มชำระ (สร้าง QR)

Request:
```json
{ "method": "onepay" }
```

Response ที่ต้องการ:
```json
{
  "success": true,
  "data": {
    "transactionRef": "...",
    "billNo": "2607-00020",        // ⭐ เพิ่ม
    "paymentNo": "SK2607-00002",   // ⭐ เพิ่ม
    "method": "onepay",
    "qrString": "00020101021138...",
    "paymentUrl": null
  }
}
```

NestJS DTO:
```ts
export class InitiatePaymentResponseDto {
  transactionRef: string;
  billNo: string | null;      // ⭐ เพิ่ม
  paymentNo: string | null;   // ⭐ เพิ่ม — เลขที่การชำระ (SK...)
  method: string;
  qrString?: string | null;
  paymentUrl?: string | null;
}
```

**❓ คำถามที่ต้องตอบกลับ:** `transactionRef` ที่ส่งอยู่ตอนนี้ คือค่าเดียวกับ `Payment No.` (`SK2607-00002`) ไหม
- ถ้าใช่ → ไม่ต้องเพิ่ม `paymentNo` แค่ยืนยันกลับมา แล้วแอปจะใช้ `transactionRef` แทน
- ถ้าไม่ (เป็น ref ของ OnePay) → เพิ่ม `paymentNo` ตามด้านบน

---

### 2.3 `GET /orders/:orderId/payment-status` — ⭐ สำคัญที่สุด

แอป poll endpoint นี้ **ทุก 3 วินาที** (timeout 5 นาที) ระหว่างรอผู้ใช้สแกน QR
**ทันทีที่ได้ `isPaid: true` แอปจะเด้งเข้าหน้าใบเสร็จและ save รูปอัตโนมัติ**
→ ถ้าเลขบิลไม่มากับ response นี้ barcode จะไม่มีข้อมูลให้ใช้

Response ที่ต้องการ:
```json
{
  "success": true,
  "data": {
    "isPaid": true,
    "billNo": "2607-00020",         // ⭐ เพิ่ม (จำเป็นที่สุด)
    "paymentNo": "SK2607-00002",    // ⭐ เพิ่ม
    "amount": 10000,                // ⭐ เพิ่ม — ยอดที่ชำระจริง
    "bankRef": "BCEL123456789",
    "paidAt": "2026-07-30T19:16:52.000Z"
  }
}
```

NestJS DTO:
```ts
export class PaymentStatusResponseDto {
  isPaid: boolean;
  billNo: string | null;      // ⭐ เพิ่ม
  paymentNo: string | null;   // ⭐ เพิ่ม
  amount: number | null;      // ⭐ เพิ่ม (LAK, integer)
  bankRef?: string | null;
  paidAt?: string | null;     // ISO 8601 + timezone
}
```

---

## 3. ตารางสรุป field ที่ขอ

| field | type | ตัวอย่าง | pickup/forward | pay | payment-status |
|---|---|---|---|---|---|
| `billNo` | `string \| null` | `"2607-00020"` | ✅ | ✅ | ✅ **จำเป็น** |
| `paymentNo` | `string \| null` | `"SK2607-00002"` | – | ✅ | ✅ |
| `amount` | `number \| null` | `10000` | (มีแล้ว) | – | ✅ |
| `paidAt` | ISO string | `"2026-07-30T19:16:52.000Z"` | – | – | (มีแล้ว) |

---

## 4. ข้อกำหนดที่ต้องทำตาม

1. **ชื่อ field เป็น camelCase** ให้ตรงแนวเดิม (`paymentStatus`, `transactionRef`, `paidAt`) — ไม่ใช่ `bill_no`
   ถ้าฝั่ง entity/DB เป็น snake_case ให้ map ที่ชั้น DTO / serializer
2. **`billNo` ต้องเ��็น string** ห้ามส่งเป็น number — เลขนำหน้าและ `-` ต้องคงรูป `YYMM-NNNNN`
   (ส่งเป็น number จะกลายเป็น `2607` แล้วส่วน running หาย)
3. **`amount` เป็น integer LAK ไม่มีทศนิยม** (LAK ไม่มีหน่วยย่อย) ห้ามส่ง `10000.00` เป็น string
4. **`paidAt` เป็น ISO 8601 พร้อม timezone** (`...Z` หรือ `+07:00`) — แอปแปลงเป็น local time เอง
   ถ้าส่งมาแบบไม่มี timezone แอปจะตีความเป็น local แล้วเวลาบนใบเสร็จอาจคลาดไป 7 ชม.
5. **ห้ามลบ / เปลี่ยนชื่อ field เดิม** — เพิ่มของใหม่เท่านั้น (แอปเวอร์ชันที่อยู่ในมือผู้ใช้แล้วต้องไม่พัง)
6. **คงรูป envelope เดิม** `{ "success": true, "data": { ... } }`
7. `null` ได้ในกรณีที่ยังไม่ออกเลข แต่ **ตอน `isPaid: true` ต้องมี `billNo` เสมอ**
8. **`billNo` เดิมเสมอสำหรับ order เดียวกัน** — poll หลายรอบ / เรียกซ้ำ ต้องได้เลขเดิม ห้าม gen ใหม่ทุกครั้ง

---

## 5. รูปแบบเลข (ยืนยันกับ back office)

จากข้อมูลที่เห็นในหน้า Payment:

| | รูปแบบ | ตัวอย่าง | ความหมาย |
|---|---|---|---|
| Bill No. | `YYMM-NNNNN` | `2607-00020` | ปี 26 เดือน 07 + running 5 หลัก |
| Payment No. | `SK` + `YYMM-NNNNN` | `SK2607-00002` | prefix `SK` + running แยกอีกชุด |

ข้อสังเกต: running ของ Bill No. เดินต่อกัน (`2607-00019`, `2607-00020`) และ reset ตามเดือน
**ถ้าเลขนี้ generate อยู่ที่ระบบ back office (Laravel) แล้ว ให้ NestJS ดึงมา relay ไม่ต้อง gen ใหม่** — จะได้ไม่เกิดเลขซ้อนกัน 2 ชุด

⚠️ Race condition: ถ้า NestJS เป็นฝ่าย gen เอง ให้ล็อกด้วย DB sequence / `SELECT ... FOR UPDATE` หรือ unique index บน `bill_no` — ไม่ใช่ `MAX(no) + 1` เฉยๆ เพราะจ่ายพร้อมกันหลายคนจะได้เลขซ้ำ

---

## 6. Barcode

- แอปเข้ารหัสด้วย **Code128** จากค่า `billNo` **ตรงๆ ไม่มีการเติม prefix/checksum เอง**
- backend **ไม่ต้องส่งรูป barcode มา** — แอป render เอง ส่งมาแต่ string
- ต้องมั่นใจว่าเครื่องสแกน/ระบบแอดมิน **ค้นหาด้วยค่านี้ได้ตรงตัว** (ค่าที่สแกนได้จะเท่ากับ `billNo` เป๊ะ เช่น `2607-00020` รวมขีดกลาง)
- ถ้าฝั่งแอดมินต้องการค่าที่สแกนเป็นอย่างอื่น (เช่นไม่มีขีด หรือเป็น order id) **บอกมาก่อน** จะได้ปรับให้ตรงกัน

---

## 7. Checklist ให้ backend

- [ ] เพิ่ม `billNo` ใน response ของ `POST /orders/pickup` และ `POST /orders/forward`
- [ ] เพิ่ม `billNo`, `paymentNo` ใน response ของ `POST /orders/:orderId/pay`
- [ ] เพิ่ม `billNo`, `paymentNo`, `amount` ใน response ของ `GET /orders/:orderId/payment-status` ⭐
- [ ] ยืนยันว่า `paidAt` มี timezone
- [ ] ตอบกลับว่า `transactionRef` = `Payment No.` หรือไม่
- [ ] ยืนยันรูปแบบเลข `YYMM-NNNNN` และแหล่งที่ gen (Laravel หรือ NestJS)
- [ ] ยืนยันว่าค่าที่ให้ทำ barcode คือ `billNo` ตรงตัว

---

## 8. ฝั่งแอปพร้อมแล้ว

แอป parse field ทั้งหมดข้างบนไว้เรียบร้อยแล้ว (`lib/features/parcel_payment/data/payment_repository.dart`)
เป็น optional ทั้งหมด → **ส่งมาได้เลยไม่ต้องรอ release แอปใหม่**

พฤติกรรมระหว่างที่ยังไม่ส่ง:
- แถว Bill No. / Payment No. ถูกซ่อน (ไม่ขึ้นแถวว่าง)
- barcode fallback ไปใช้ `order.id` — สแกนได้แต่ไม่ตรงกับหลังบ้าน
- วันที่/เวลา fallback เป็นเวลาบนเครื่องผู้ใช้ตอนจ่ายสำเร็จ

พอส่ง field มา ใบเสร็จจะขึ้นครบทันที
