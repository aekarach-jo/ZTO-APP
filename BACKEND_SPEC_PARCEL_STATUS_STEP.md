# Spec สำหรับ Backend (NestJS): Step Tracker + BillNo/PaymentNo ใน Order History

**ผู้ขอ:** ทีม Mobile (ZTO_APP / Flutter)
**วันที่:** 2026-08-03
**Base URL:** `http://14.207.141.82/api/v1`
**เกี่ยวข้องกับ:** `BACKEND_SPEC_PAYMENT_RECEIPT.md` (เรื่อง billNo/paymentNo — ฉบับนี้ขยายไปยัง endpoint อื่น)

---

## 1. สรุปสั้นๆ ว่าต้องทำอะไร

| # | Endpoint | สิ่งที่ต้องแก้ | ความสำคัญ |
|---|----------|----------------|-----------|
| 1 | `GET /parcels/status` | เปลี่ยนเงื่อนไขคำนวณ `step` = 3 ให้ผูกกับ **ชำระเงินสำเร็จ** | ⭐⭐⭐ |
| 2 | `GET /parcels/status` | เพิ่ม `bill_no` + `payment_no` ใน object `order` | ⭐⭐⭐ |
| 3 | `GET /parcels/status` | `step` = 4 เมื่อ **แอดมิน approve payment** + **กรองพัสดุนั้นออกจาก list และ counts** | ⭐⭐⭐ |
| 4 | `GET /orders` | เพิ่ม `billNo` + `paymentNo` ในทุก item (หน้า Order History) | ⭐⭐⭐ |
| 5 | `GET /orders/{orderId}` | เพิ่ม `paymentNo` (`billNo` มีแล้ว) | ⭐⭐ |
| 6 | ทุกเส้น | รักษา naming convention เดิมของแต่ละเส้น (ดูข้อ 6) | ⭐⭐ |

---

## 2. นิยาม Step Tracker ที่ต้องการ

หน้า **สถานะพัสดุ** ในแอปแสดงแถบ 4 จุดต่อพัสดุหนึ่งใบ:

```
 ①──────②──────③──────④
Arrived  Ready  Delivering  Done
```

แอปอ่านค่า `step` (int 1-4) จาก API ตรงๆ **ไม่มี logic ตัดสินใจฝั่งแอปเลย**
(`parcel_status_repository.dart:135` → `parcel_status_screen.dart:443-463`)

### เงื่อนไขของแต่ละ step

| step | Label | เงื่อนไขที่ต้องการ | สถานะปัจจุบัน |
|------|-------|--------------------|----------------|
| 1 | Arrived | พัสดุถึงโกดัง / รอตรวจสอบ | ✅ ถูกแล้ว ไม่ต้องแก้ |
| 2 | Ready | ตรวจสอบเสร็จ พร้อมให้ลูกค้าชำระเงิน | ✅ ถูกแล้ว ไม่ต้องแก้ |
| 3 | **Delivering** | **ลูกค้าชำระเงินสำเร็จ** (payment settled / `paymentStatus = paid`) | ⛔ ต้องแก้ |
| 4 | **Done** | **แอดมินฝั่งเว็บกด Approve Payment** | ⛔ ต้องแก้ |

> **สำคัญ:** step 3 ต้องไม่ผูกกับสถานะขนส่ง (`in_transit` / `shipping_started`) อีกต่อไป
> ตัวตัดสินคือ **การชำระเงินสำเร็จ** เท่านั้น

---

## 3. `GET /parcels/status` — สิ่งที่ต้องแก้

### 3.1 เงื่อนไข step 3

เมื่อ payment ของ order ที่ผูกกับพัสดุนั้น settle สำเร็จ → `step` ต้องเป็น `3` ทันที
(ไม่ต้องรอสถานะขนส่ง ไม่ต้องรอแอดมิน)

### 3.2 ⭐ เพิ่ม `bill_no` และ `payment_no` ใน object `order`

ตอนนี้ object `order` ส่งมาแค่นี้ (แอป parse ที่ `parcel_status_repository.dart:77-93`):

```json
"order": {
  "nest_order_id": "...",
  "type": "pickup",
  "amount_lak": 10000,
  "method": "onepay",
  "payment_ref": "...",
  "paid_at": "2026-08-03T10:00:00Z"
}
```

**ต้องเพิ่ม 2 field นี้** (ส่งมาพร้อมกันตอน step ขึ้นเป็น 3):

```json
"order": {
  "nest_order_id": "...",
  "type": "pickup",
  "amount_lak": 10000,
  "method": "onepay",
  "payment_ref": "...",
  "paid_at": "2026-08-03T10:00:00Z",
  "bill_no": "2608-00031",      // ⭐ ใหม่ — เลขบิล
  "payment_no": "SK2608-00012"  // ⭐ ใหม่ — เลข payment
}
```

- ใช้ **snake_case** ตาม convention ของเส้นนี้ (ดูข้อ 6)
- ต้องเป็นเลขเดียวกับที่โชว์ในหน้าใบเสร็จ (`GET /orders/{id}/payment-status`) และในหน้า Payment ของ back office
- ถ้ายังไม่ชำระเงิน (step 1-2) ส่ง `null` หรือไม่ต้องส่ง field มาก็ได้ — แอปซ่อนแถวที่ค่าว่างอยู่แล้ว

### 3.3 ⭐ step 4 + กรองออกจากรายการ

เมื่อแอดมินฝั่งเว็บกด **Approve Payment**:
- `step` ของพัสดุนั้นเป็น `4`
- **ไม่ต้องส่งพัสดุใบนั้นมาใน array `parcels` อีก**
- **`counts` ต้องไม่นับรวมด้วย** (`in_progress` / `self_pickup` / `forwarded` ต้องลดลงตาม) — ไม่งั้นตัวเลขบนการ์ดจะไม่ตรงกับจำนวนรายการที่แสดง ⚠️
- ประวัติจะไปดูที่หน้า **Order History** แทน (ข้อ 4)

> ⚠️ **จุดที่ต้องตัดสินใจ (ดูข้อ 7.1):** ถ้ากรองออกทันที ผู้ใช้จะ**ไม่มีวันเห็นจุดที่ 4 ติด**เลย
> เพราะรายการหายไปในการ refresh ครั้งเดียวกับที่ step กลายเป็น 4

### 3.4 ต้องไม่ให้ `step` หลุดช่วง 1-4

- ต้องเป็น int เสมอ ไม่ใช่ `null` / string ว่าง / `0`
- แอปไม่ได้ clamp ค่า → ส่ง `0` มาจะไม่มีจุดติดเลย, ส่ง `7` มาจะติดหมดทั้งแถวโดยไม่ error
- ถ้าไม่มีค่ามา แอป default เป็น `1`

### 3.5 `step_label` เป็น dead field

backend ส่ง `step_label` มาแต่ **แอปไม่ได้ใช้แสดงผลเลย** (แอปใช้ label แปลเองเพราะรองรับ th/en/lo/zh)
→ ตัดออกได้ ลด payload

---

## 4. `GET /orders` — สิ่งที่ต้องแก้ (หน้า Order History)

หน้า Order History (`order_history_screen.dart`) ตอนนี้แสดงแค่: ประเภท (pickup/forward), ชื่อผู้รับ, ยอดเงิน, วันที่, สถานะการจ่าย
**ต้องการเพิ่ม BillNo และ PaymentNo ในทุกรายการ**

ปัจจุบันแอป parse ที่ `order_repository.dart:50-63`:

```json
{
  "id": "...",
  "type": "pickup",
  "paymentStatus": "paid",
  "amount": 10000,
  "currency": "LAK",
  "recipientName": "...",
  "createdAt": "2026-08-03T09:00:00Z",
  "paidAt": "2026-08-03T10:00:00Z"
}
```

**ต้องเพิ่ม:**

```json
{
  "...": "...",
  "billNo": "2608-00031",        // ⭐ ใหม่
  "paymentNo": "SK2608-00012"    // ⭐ ใหม่
}
```

- ใช้ **camelCase** ตาม convention ของเส้นนี้ (ต่างจาก `/parcels/status` — ดูข้อ 6)
- order ที่ยังไม่จ่าย (`paymentStatus: "pending"`) ส่ง `null` ได้ แอปจะซ่อนแถวนั้น
- ⚠️ order ที่แอดมิน approve แล้ว **ต้องยังอยู่ใน `GET /orders`** — เพราะถูกกรองออกจาก `/parcels/status` ไปแล้ว ถ้าหายจากที่นี่ด้วยจะไม่เหลือที่ให้ผู้ใช้ดูประวัติเลย

---

## 5. `GET /orders/{orderId}` — เพิ่ม `paymentNo`

แอป parse `billNo` อยู่แล้ว (`payment_repository.dart:78`) แต่**ไม่มี `paymentNo`**
ขอให้ส่ง `paymentNo` มาด้วย (camelCase) เพื่อให้ทุกเส้นสอดคล้องกัน

**สรุป field billNo/paymentNo ที่ต้องมีครบทุกเส้น:**

| Endpoint | `billNo` | `paymentNo` | naming |
|----------|----------|-------------|--------|
| `GET /parcels/status` → `order` | ⭐ ต้องเพิ่ม | ⭐ ต้องเพิ่ม | snake_case |
| `GET /orders` (list) | ⭐ ต้องเพิ่ม | ⭐ ต้องเพิ่ม | camelCase |
| `GET /orders/{id}` | ✅ มีแล้ว | ⭐ ต้องเพิ่ม | camelCase |
| `GET /orders/{id}/payment-status` | ขอไว้แล้ว | ขอไว้แล้ว | camelCase |
| `POST /orders/{id}/pay` | optional | optional | camelCase |

---

## 6. ⚠️ Naming convention ต่างกันระหว่างเส้น — ห้ามสลับ

แอปมี parser คนละตัวสำหรับสองกลุ่มนี้ **ส่งผิดแบบ = แอปอ่านไม่เจอ ขึ้นค่าว่างเงียบๆ ไม่ error**

| กลุ่ม | Endpoint | รูปแบบ | ตัวอย่าง field ปัจจุบัน |
|-------|----------|--------|------------------------|
| A | `GET /parcels/status` | **snake_case** | `track_no`, `step_label`, `payment_ref`, `paid_at`, `nest_order_id`, `amount_lak`, `is_forward`, `created_at` |
| B | `/orders*` ทุกเส้น | **camelCase** | `paymentStatus`, `recipientName`, `createdAt`, `paidAt`, `billNo`, `shippingFee`, `itemTotal` |

→ `/parcels/status` ใช้ `bill_no` / `payment_no`
→ `/orders*` ใช้ `billNo` / `paymentNo`

(ถ้า backend อยากรวมเป็นแบบเดียวทั้งระบบ บอกมาได้ แอปแก้ parser ให้ แต่ต้องแจ้งก่อนเพื่อ deploy พร้อมกัน)

---

## 7. คำถามที่ต้องการคำตอบ

### 7.1 ⚠️ step 4 จะแสดงให้ผู้ใช้เห็นตอนไหน?

Requirement บอกว่า "แสดง step 4" **และ** "กรองออกจากรายการ" — สองอย่างนี้ขัดกัน
ถ้ากรองออกทันทีที่ approve ผู้ใช้จะไม่มีทางเห็นจุดที่ 4 ติดเลย

ทางเลือก:
- **(ก) กรองออกทันที** — จุดที่ 4 ไม่เคยแสดงจริง เป็นแค่ค่าใน API / ผู้ใช้ไปดูผลที่ Order History แทน
- **(ข) ส่งมาต่ออีกช่วงหนึ่ง** — เช่น ยังส่งพัสดุ step 4 มาอีก 24 ชม. หลัง approve แล้วค่อยหาย ผู้ใช้ได้เห็น tracker เต็ม
- **(ค) ส่งมาเสมอ + ให้แอปกรองเอง** — backend ส่ง step 4 มาด้วยพร้อม flag เช่น `approved_at` แล้วแอปจัดการ UI เอง (ยืดหยุ่นที่สุด ไม่ต้องแก้ backend อีกถ้าเปลี่ยนใจ)

**ทีม Mobile แนะนำ (ค) หรือ (ข)** — รอฝั่ง requirement ยืนยัน

### 7.2 "Approve Payment" ฝั่งเว็บมีสถานะเก็บอยู่แล้วหรือยัง?

- มี field/ตารางไหนเก็บผลการ approve อยู่แล้วไหม (เช่น `approvalStatus`, `approvedAt`, `approvedBy`)
- ถ้ามี ขอชื่อ field มาด้วย เผื่อแอปอยากแสดงใน Order History ("รออนุมัติ" / "อนุมัติแล้ว")
- ถ้ายังไม่มี ต้องเพิ่มก่อน เพราะเป็นตัวตัดสิน step 4

### 7.3 `self_pickup` ที่ลูกค้ามารับเอง — step 3 หมายถึงอะไร?

flow นี้ไม่มีการจัดส่ง แต่ใช้ tracker ชุดเดียวกัน
ตามนิยามใหม่ (step 3 = จ่ายเงินสำเร็จ) น่าจะใช้ได้ทุก category — ขอให้ backend ยืนยันว่าใช้ logic เดียวกันหมดทั้ง `in_progress` / `self_pickup` / `forwarded`

### 7.4 หนึ่ง order ครอบหลายพัสดุ

`ParcelOrder.items` รองรับหลายพัสดุต่อ 1 order อยู่แล้ว
→ ถ้าแอดมิน approve order เดียวที่มี 3 พัสดุ ต้องขึ้น step 4 และกรองออกทั้ง 3 ใบพร้อมกันใช่ไหม?

---

## 8. Checklist สำหรับ Backend

- [ ] `GET /parcels/status`: `step = 3` เมื่อชำระเงินสำเร็จ (เลิกผูกกับสถานะขนส่ง)
- [ ] `GET /parcels/status`: เพิ่ม `order.bill_no` + `order.payment_no` (snake_case)
- [ ] `GET /parcels/status`: `step = 4` เมื่อแอดมิน approve payment
- [ ] `GET /parcels/status`: กรองพัสดุ step 4 ออกจาก `parcels` **และ** หักออกจาก `counts` (รอสรุปข้อ 7.1)
- [ ] `GET /parcels/status`: การันตี `step` เป็น int ช่วง 1-4 เสมอ
- [ ] `GET /parcels/status`: ตัด `step_label` ออก (optional)
- [ ] `GET /orders`: เพิ่ม `billNo` + `paymentNo` ทุก item (camelCase)
- [ ] `GET /orders`: order ที่ approve แล้วต้องยังคงอยู่ในลิสต์
- [ ] `GET /orders/{id}`: เพิ่ม `paymentNo`
- [ ] ตอบคำถามข้อ 7.1 - 7.4

---

## 9. ไฟล์ฝั่งแอปที่เกี่ยวข้อง (ให้ทีม Mobile แก้ต่อ)

| ไฟล์ | สิ่งที่ต้องแก้ฝั่งแอป |
|------|----------------------|
| `lib/features/parcel_status/data/parcel_status_repository.dart` | เพิ่ม parse `bill_no` / `payment_no` ใน `ParcelStatusOrder` |
| `lib/features/parcel_status/presentation/screens/parcel_status_screen.dart:555` | `_OrderSummary` แสดง BillNo / PaymentNo |
| `lib/features/orders/data/order_repository.dart:50` | เพิ่ม `billNo` / `paymentNo` ใน `OrderSummary` |
| `lib/features/orders/presentation/screens/order_history_screen.dart:89` | แสดง BillNo / PaymentNo ในการ์ด |
| `lib/features/parcel_payment/data/payment_repository.dart:68` | เพิ่ม `paymentNo` ใน `ParcelOrder` |
| `assets/translations/{th,en,lo,zh}.json` | key ใหม่สำหรับ label BillNo / PaymentNo ในหน้า Order History (ที่หน้าใบเสร็จมี `pickup_payment_receipt_bill_no` / `_payment_no` แล้ว) |
