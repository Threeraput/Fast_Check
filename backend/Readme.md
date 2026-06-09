*/
(.venv)

************************************************************
This software includes code from face_recognition
Copyright (c) 2021 Adam Geitgey
Licensed under the MIT License
************************************************************

คำสั่งในการเข้า 
Activate Virtual Environment
To use the virtual environment, you have to activate it with this command:
C:\Users\Your Name> myfirstproject\Scripts\activate โดยที่ชื่อ myfirstproject ก็เปลี่ยนให้เป็นชื่อที่เราต้องการจะเข้าไป
ในที่นี้จะเป็น .venv\Scripts\activate เเต่ตำเเหน่งที่อยู่ตรงเป็นใน Folder ที่มีไฟล์ .env อยู่ด้วย ณ ที่นี้อยู่ใน backend ก็ cd เข้าไปใน backend ด้วยอย่าลืม
🔍 ประโยชน์ของการ activate .venv:
เหตุผล	อธิบาย
✅ แยก dependency	คุณสามารถติดตั้งไลบรารีเฉพาะสำหรับโปรเจกต์นี้ โดยไม่กระทบไลบรารีของระบบหรือโปรเจกต์อื่น
✅ ใช้ pip install ได้อย่างปลอดภัย	เมื่อคุณรัน pip install ... จะติดตั้งเฉพาะใน venv นี้ ไม่ใช่ทั่วทั้งเครื่อง
✅ ใช้ Python เวอร์ชันที่ต้องการ	คุณสามารถสร้าง venv ด้วย Python เวอร์ชันเฉพาะที่เข้ากันกับโปรเจกต์
✅ สนับสนุนความปลอดภัย	ลดความเสี่ยงจากการรันไลบรารีที่ไม่เข้ากัน หรือ conflict
✅ ใช้ร่วมกับ .env และไฟล์ config	เมื่อคุณ activate venv แล้ว รันโปรเจกต์ Python จะสามารถโหลดค่าจาก .env ได้ตามคาดผ่าน python-dotenv หรือ pydantic
/*

*/
หลังจากได้ (.venv) C:\face\face_attendance_app\backend> มาเเล้ว
ต่อไปจะทำการเชื่อมเข้า FastApi ด้วยคำสั่งการเข้า
จะอยู่ใน doc ของ FastApi ในเรื่อง Tutorial - User Guide คำสั่งของมันคือ
fastapi dev main.py เเต่ว่าถ้า รัน จะไม่สามารถเปิดได้ เพราะ มันจะขึ้น
 FastAPI   Starting development server 🚀

             Searching for package file structure from directories with __init__.py files

             Path does not exist main.py
ความหมายก็คือ หาไฟล์ ของ main.py ซึ่งถ้าเราไปดูตำเเหน่งไฟล์ของมัน มันจะอยู่ใน app อีกที่เเล้วมันถึงจะไปถึง main.py เพราะฉะนั้นเลยใช้เป็นคำสั่งนี้
fastapi dev app/main.py ก็คือคำถึง app ก่อนเเล้วค่อยไปเรียกใช้ main.py 
              server   Server started at http://127.0.0.1:8000
              server   Documentation at http://127.0.0.1:8000/docs
/*

/*
หลังจาก รันเข้า .venv เเล้ว ทำการเชื่อม FastApi ขึ้นเเล้ว
หลังจากนั้นก็ Run ตัว Flutter ได้เลย
ถ้าไม่ขึ้นมีวิธีสำรองคือเปลี่ยน port เป็น 10.0.2.2:8000 ทั้ง 2 ไฟล์ ได้เเก่
1.auth_service.dart --> const String API_BASE_URL = 'http://10.0.2.2:8000/api/v1';
2.main.py --> "http://10.0.2.2:8000", # IP Address ของเครื่องที่รัน Backend
*/

*/
หลังจากเชื่อม .venv เชื่อม FastApi เเล้ว ต่อมา
จะทำเรื่อง OTP เพิ่ม 
1.ติดตั้ง pip install fastapi-mail ใน (.venv) C:\face\face_attendance_app\backend> ให้เรียบร้อย
2.ก็ไปทำการสมัคร app passwords google --> https://support.google.com/accounts/answer/185833?hl=en เพื่อเอามาใช้เป็นเมลส่ง OTP 
2.1 https://temp-mail.org/ เอาไว้ใช้เป็น เมล สำหรับลอง test ส่ง OTP 
3.ติดตั้ง pip install alembic จะมีไฟล์ที่เกี่ยวกับ alembic.ini
/*

คำสั่ง เปิด server uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
