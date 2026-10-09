# คอร์สแวร์ วิทยาการคำนวณ ว23101 (เทคโนโลยีความจริงเสริม)

แอปพลิเคชันคอร์สแวร์ (CAI) สำหรับรายวิชาวิทยาการคำนวณ ระดับชั้นมัธยมศึกษาปีที่ 3 โรงเรียนบ้านปลาดุกมีเกล็ด พัฒนาขึ้นในรูปแบบ Single Page Application (SPA) ด้วย HTML, CSS, JavaScript บริสุทธิ์ และใช้ **Supabase** เป็นระบบจัดการฐานข้อมูลหลังบ้าน (Backend-as-a-Service)

## ✨ ฟีเจอร์หลัก
*   **ระบบจัดการสิทธิ์ผู้ใช้งาน (Role-based Access):** แยกส่วนการทำงานระหว่าง "ผู้เรียน" และ "ผู้สอน"
*   **ระบบลงทะเบียนด้วยรหัสนักศึกษา:** ผูกบัญชีกับฐานข้อมูลนักเรียนโดยอัตโนมัติ (รหัส 11 หลัก)
*   **แบบทดสอบคู่ขนาน (A/B Testing):** ระบบสุ่มข้อสอบก่อนเรียน/หลังเรียนชุด A หรือ B ตามเลขท้ายคู่คี่ของรหัสนักศึกษา เพื่อลดผลกระทบจากการจำข้อสอบ
*   **เนื้อหาแบบโต้ตอบ (Interactive Lessons):** 
    *   เรียนรู้ผ่านการอ่านและตอบคำถามแทรก
    *   ปลดล็อกเนื้อหาหน่วยถัดไปเมื่อเรียนจบหน่วยปัจจุบัน
    *   มีสื่อ AR 3 มิติในตัว (ผ่าน `<model-viewer>`)
*   **ระบบคำนวณความก้าวหน้า:** คำนวณค่า Normalized Gain อัตโนมัติตามหลักการของ Hake (1998)
*   **Dashboard ผู้สอน:** 
    *   ดูความก้าวหน้าและคะแนนสอบของผู้เรียนทุกคน
    *   ส่งออกรายงานเป็นไฟล์ CSV ที่รองรับภาษาไทยใน Excel
*   **ความปลอดภัยสูง (RLS):** ปกป้องข้อมูลผู้เรียนด้วย Row Level Security ในระดับฐานข้อมูล ผู้เรียนไม่สามารถแก้คะแนนตัวเอง หรือดูข้อมูลเพื่อนได้

## 📂 โครงสร้างไฟล์
1.  `courseware.html`: ไฟล์หลักของแอปพลิเคชัน รวม UI (CSS) และ Logic (JavaScript) ทั้งหมด
2.  `setup.sql`: สคริปต์สำหรับตั้งค่าฐานข้อมูล สร้างตาราง ทริกเกอร์ และนโยบายความปลอดภัย (RLS) บน Supabase

---

## 🚀 คู่มือการติดตั้ง (สำหรับผู้สอน)

### ส่วนที่ 1: การตั้งค่าฐานข้อมูล (Supabase)
1. ไปที่เว็บไซต์ [Supabase](https://supabase.com) สมัครสมาชิกและสร้าง Project ใหม่
2. ไปที่เมนู **Authentication > Providers** เลือก **Email** และ **ปิดการตั้งค่า "Confirm email"** เพื่อให้นักเรียนเข้าใช้งานได้ทันทีหลังสมัคร
3. ไปที่เมนู **SQL Editor** คัดลอกโค้ดทั้งหมดจากไฟล์ `setup.sql` วางลงในช่อง และกดปุ่ม **Run**
4. ไปที่เมนู **Storage** ตรวจสอบว่ามี Bucket 3 ใบถูกสร้างขึ้น ได้แก่ `photos`, `submissions`, และ `materials` (หากไม่มี ให้กด Create Bucket สร้างเอง โดย **ไม่ต้อง** ติ๊กช่อง Public)
5. ไปที่เมนู **Table Editor** เลือกตาราง `students` กดปุ่ม **Insert > Import data from CSV** เพื่ออัปโหลดรายชื่อนักเรียน (ไฟล์ CSV ต้องมีคอลัมน์ `id, title, first_name, last_name, section`)

### ส่วนที่ 2: การตั้งค่าแอปพลิเคชัน (HTML)
1. ในหน้า Dashboard ของ Supabase ไปที่เมนู **Project Settings > API**
2. คัดลอกค่า **Project URL** และ **anon public key**
3. เปิดไฟล์ `courseware.html` ด้วยโปรแกรมแก้ไขข้อความ (เช่น Notepad, VS Code)
4. เลื่อนไปที่บรรทัดประมาณ 166-167 และนำค่าที่ได้ไปใส่ในตัวแปร:
   ```javascript
   const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co'; 
   const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
   ```
5. บันทึกไฟล์

### ส่วนที่ 3: การตั้งค่าบัญชีผู้สอน
1. เปิดไฟล์ `courseware.html` ในเว็บเบราว์เซอร์
2. ไปที่ส่วนลงทะเบียน พิมพ์อีเมลของคุณ (เช่น `teacher@banpladuk.ac.th`) และตั้งรหัสผ่าน เพื่อลงทะเบียนบัญชีใหม่
3. กลับไปที่ **SQL Editor** ใน Supabase
4. นำเครื่องหมาย `--` ออกจาก 2 บรรทัดสุดท้ายในไฟล์ `setup.sql` เปลี่ยนอีเมลเป็นของคุณ แล้วกด **Run**:
   ```sql
   INSERT INTO public.teachers (user_id)
   SELECT id FROM auth.users WHERE email = 'teacher@banpladuk.ac.th';
   ```
5. รีเฟรชหน้าเว็บคอร์สแวร์ คุณจะเข้าสู่ระบบในฐานะ "ผู้สอน"

---

## 💻 การเผยแพร่ (Deployment)
เนื่องจากเป็นไฟล์ HTML เดี่ยว คุณสามารถส่งไฟล์ `courseware.html` ให้นักเรียนเปิดในเครื่องได้โดยตรง หรืออัปโหลดขึ้นบริการโฮสติ้งฟรี เช่น:
*   [GitHub Pages](https://pages.github.com/)
*   [Vercel](https://vercel.com/)
*   [Netlify](https://www.netlify.com/)

---

## 📚 แหล่งอ้างอิงทางวิชาการที่ใช้ในระบบ
*   **Azuma, R. T. (1997).** A Survey of Augmented Reality.
*   **Milgram, P., & Kishino, F. (1994).** A Taxonomy of Mixed Reality Visual Displays.
*   **Mayer, R. E. (2001).** Multimedia Learning (Spatial Contiguity Principle).
*   **Rovinelli, R. J., & Hambleton, R. K. (1977).** On the use of content specialists in the assessment of criterion-referenced test item validity (IOC).
*   **Hake, R. R. (1998).** Interactive-engagement versus traditional methods: A six-thousand-student survey of mechanics test data for introductory physics courses (Normalized Gain).