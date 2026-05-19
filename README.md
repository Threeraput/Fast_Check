# Fast_Check (Faculty Attendance Application)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white) ![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white) ![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)

**Fast_Check** คือแอปพลิเคชันบนมือถือที่พัฒนาด้วย Flutter สำหรับระบบเช็คชื่อเข้าเรียนของคณะ โดยเน้นไปที่ความแม่นยำและความปลอดภัย ป้องกันการทุจริตในการเช็คชื่อแทนกันผ่านการยืนยันตัวตนและพิกัดตำแหน่ง

---

## Key Features (ฟีเจอร์เด่น)

### 1. Smart Verification (ระบบยืนยันตัวตนและตำแหน่ง)
* **GPS Radius Check:** ตรวจสอบพิกัดตำแหน่ง (Latitude, Longitude) ของผู้ใช้งานแบบเรียลไทม์ โดยระบบจะอนุญาตให้เช็คชื่อได้ก็ต่อเมื่ออยู่ในรัศมีของห้องเรียนที่กำหนดเท่านั้น
* **Face Verification:** บูรณาการระบบสแกนใบหน้าเพื่อยืนยันตัวตนนักศึกษาแต่ละคน เพิ่มความปลอดภัยขั้นสุดในการเข้าเรียน

### 2. Data Persistence & Management (ระบบจัดการชั้นเรียน)
* **Class Archive System:** ออกแบบระบบจัดการชั้นเรียนให้ใช้ฟังก์ชัน "Archive (จัดเก็บเข้าคลัง)" แทนการ "Delete (ลบ)" เพื่อป้องกันข้อมูลสูญหาย ทำให้มั่นใจได้ว่าประวัติการเช็คชื่อและข้อมูลทางสถิติของเทอมก่อนๆ จะยังคงอยู่และสามารถเรียกดูย้อนหลังได้เสมอ

### 3. Smart UI/UX (ประสบการณ์ผู้ใช้งาน)
* **Intuitive Report Generation:** ระบบออกรายงานที่ออกแบบ UI มาเพื่อความสะดวกรวดเร็ว เช่น เมนู Dropdown เลือกประเภทรายงานที่จะมีค่าเริ่มต้นเป็น "Select All" และมีลอจิก Auto-select เลือกค่าให้อัตโนมัติในกรณีที่มีตัวเลือกเพียงรายการเดียว ช่วยลดขั้นตอนการกดของผู้ใช้งาน (Click Reduction)

---

## 🛠️ Tech Stack & Architecture
* **Framework:** Flutter (Dart)
* **Core Libraries:** * `geolocator` (สำหรับจัดการ GPS และคำนวณระยะทาง)
    * https://github.com/ageitgey/face_recognition []
* **Architecture Pattern:** []

---

## 📸 Screenshots (ภาพตัวอย่างการใช้งาน)
*(แนะนำ: นำรูปภาพแคปหน้าจอแอปของคุณมาใส่ตรงนี้ เช่น หน้าสแกนหน้า, หน้าเช็คพิกัด หรือหน้า Archive)*
<p float="left">
  <img src="ใส่ลิงก์รูปภาพที่1ตรงนี้" width="200" />
  <img src="ใส่ลิงก์รูปภาพที่2ตรงนี้" width="200" /> 
  <img src="ใส่ลิงก์รูปภาพที่3ตรงนี้" width="200" />
</p>

---

## 🚀 How to Run (วิธีการติดตั้ง)

1. Clone the repository
   ```bash
   git clone [https://github.com/Threeraput/Fast_Check.git](https://github.com/Threeraput/Fast_Check.git)
