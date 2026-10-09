-- ==============================================================================
-- สคริปต์ตั้งค่าฐานข้อมูล Supabase สำหรับคอร์สแวร์รายวิชา ว23101 (วิทยาการคำนวณ)
-- ข้อควรระวัง: รันทั้งหมดใน SQL Editor ของ Supabase
-- ==============================================================================

-- 1. ล้างข้อมูลเก่าและกำหนดสิทธิ์พื้นฐาน
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- 2. สร้างตาราง
CREATE TABLE public.teachers (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.students (
    id VARCHAR(11) PRIMARY KEY, -- รหัสนักศึกษา 11 หลัก
    title VARCHAR(20) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    section VARCHAR(10) NOT NULL,
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    photo_path TEXT
);

CREATE TABLE public.attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind VARCHAR(4) CHECK (kind IN ('pre', 'post')),
    score INTEGER NOT NULL,
    answers JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, kind)
);

CREATE TABLE public.progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    unit INTEGER NOT NULL CHECK (unit BETWEEN 1 AND 5),
    done BOOLEAN DEFAULT FALSE,
    UNIQUE(user_id, unit)
);

CREATE TABLE public.submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    unit INTEGER NOT NULL,
    kind VARCHAR(10) CHECK (kind IN ('link', 'file')),
    url TEXT,
    storage_path TEXT,
    note TEXT,
    score INTEGER,
    teacher_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    kind VARCHAR(10) CHECK (kind IN ('file', 'link', 'video')),
    url TEXT,
    storage_path TEXT,
    file_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. เปิดใช้งาน Row Level Security (RLS)
ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials ENABLE ROW LEVEL SECURITY;

-- 4. ฟังก์ชันตรวจสอบสิทธิ์ผู้สอน (Security Definer)
CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM public.teachers WHERE user_id = auth.uid());
END;
$$;

-- 5. นโยบาย RLS (Policies)

-- Teachers: ผู้สอนเห็นรายชื่อตัวเองได้
CREATE POLICY "Teachers can view themselves" ON public.teachers FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- Students: ทุกคนเห็นชื่อเพื่อนได้ (สำหรับตารางแสดงผล) แต่แก้ได้เฉพาะรูปตัวเอง
CREATE POLICY "Authenticated users can view students" ON public.students FOR SELECT TO authenticated USING (true);
CREATE POLICY "Students can update own photo" ON public.students FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- Attempts: ผู้เรียนดูและเพิ่มของตัวเอง ผู้สอนดูทั้งหมด
CREATE POLICY "Students view own attempts" ON public.attempts FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_teacher());
CREATE POLICY "Students insert own attempts" ON public.attempts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

-- Progress: ผู้เรียนดู/เพิ่ม/แก้ ของตัวเอง ผู้สอนดูทั้งหมด
CREATE POLICY "Students view own progress" ON public.progress FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_teacher());
CREATE POLICY "Students manage own progress" ON public.progress FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Submissions: ผู้เรียนดู/เพิ่ม/แก้ ของตัวเอง ผู้สอนดู/แก้ (ให้คะแนน) ทั้งหมด
CREATE POLICY "View submissions" ON public.submissions FOR SELECT TO authenticated USING (user_id = auth.uid() OR is_teacher());
CREATE POLICY "Students insert own submissions" ON public.submissions FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Update submissions" ON public.submissions FOR UPDATE TO authenticated USING (user_id = auth.uid() OR is_teacher());

-- Materials: ทุกคนที่ล็อกอินดูได้ ผู้สอนจัดการได้
CREATE POLICY "View materials" ON public.materials FOR SELECT TO authenticated USING (true);
CREATE POLICY "Teacher manage materials" ON public.materials FOR ALL TO authenticated USING (is_teacher()) WITH CHECK (is_teacher());

-- 6. ทริกเกอร์ป้องกันผู้เรียนแก้คะแนนและข้อเสนอแนะในตาราง Submissions
CREATE OR REPLACE FUNCTION public.prevent_score_update()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT public.is_teacher() THEN
        -- ถ้าไม่ใช่ผู้สอน บังคับให้ค่าคะแนนและคอมเมนต์เป็นค่าเดิมก่อนอัปเดต
        NEW.score = OLD.score;
        NEW.teacher_comment = OLD.teacher_comment;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_submission_update
BEFORE UPDATE ON public.submissions
FOR EACH ROW EXECUTE FUNCTION public.prevent_score_update();

-- 7. ทริกเกอร์ผูกบัญชี auth.users กับนักเรียน
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    student_id VARCHAR(11);
BEGIN
    -- เช็คว่าอีเมลขึ้นต้นด้วยตัวเลข 11 หลักหรือไม่
    IF NEW.email ~ '^[0-9]{11}@' THEN
        student_id := substring(NEW.email from 1 for 11);
        -- อัปเดตตารางนักเรียน ถ้าไม่พบหรือมีคนใช้แล้วจะเกิด Exception ทำให้สมัครไม่ได้
        UPDATE public.students SET user_id = NEW.id WHERE id = student_id AND user_id IS NULL;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'รหัสนักศึกษาไม่มีในระบบ หรือถูกลงทะเบียนไปแล้ว';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 8. มุมมอง (View) สรุปผลสำหรับผู้สอน (Security Invoker)
CREATE VIEW public.results WITH (security_invoker = true) AS
SELECT 
    s.id AS student_id,
    s.first_name,
    s.last_name,
    s.section,
    pre.score AS pre_score,
    post.score AS post_score,
    (SELECT count(*) FROM public.progress WHERE user_id = s.user_id AND done = true) AS units_completed
FROM public.students s
LEFT JOIN public.attempts pre ON s.user_id = pre.user_id AND pre.kind = 'pre'
LEFT JOIN public.attempts post ON s.user_id = post.user_id AND post.kind = 'post'
WHERE s.user_id IS NOT NULL;

-- 9. Storage Buckets และ Policies
-- ต้องไปสร้าง Bucket ผ่าน Dashboard หรือ API อันนี้เป็นคำสั่งจำลองสำหรับ SQL Editor (อาจต้องใช้ Dashboard ถ้าคำสั่งเหล่านี้ไม่รองรับในบางเวอร์ชัน)
INSERT INTO storage.buckets (id, name, public) VALUES ('photos', 'photos', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('submissions', 'submissions', false) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('materials', 'materials', false) ON CONFLICT DO NOTHING;

-- นโยบาย Storage: Photos
CREATE POLICY "User manage own photo" ON storage.objects FOR ALL TO authenticated USING (bucket_id = 'photos' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "Teacher read all photos" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'photos' AND public.is_teacher());

-- นโยบาย Storage: Submissions
CREATE POLICY "User manage own submission files" ON storage.objects FOR ALL TO authenticated USING (bucket_id = 'submissions' AND auth.uid()::text = (string_to_array(name, '/'))[1]);
CREATE POLICY "Teacher read all submission files" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'submissions' AND public.is_teacher());

-- นโยบาย Storage: Materials
CREATE POLICY "Read materials" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'materials');
CREATE POLICY "Teacher manage materials files" ON storage.objects FOR ALL TO authenticated USING (bucket_id = 'materials' AND public.is_teacher());

-- 10. ข้อมูลจำลอง (นำเข้ารายชื่อจริงด้วย CSV ผ่าน Table Editor ภายหลัง)
INSERT INTO public.students (id, title, first_name, last_name, section) VALUES
('11111111111', 'เด็กชาย', 'สมชาย', 'เรียนดี', '3/1'),
('11111111112', 'เด็กหญิง', 'สมหญิง', 'ขยันยิ่ง', '3/1'),
('11111111113', 'เด็กชาย', 'มานะ', 'อดทน', '3/2'),
('11111111114', 'เด็กหญิง', 'ปิติ', 'ยินดี', '3/2'),
('11111111115', 'เด็กชาย', 'ชูใจ', 'รักเรียน', '3/3'),
('11111111116', 'เด็กหญิง', 'ใบบัว', 'บานชื่น', '3/3');

-- ==============================================================================
-- คำสั่งสำหรับตั้งค่าผู้สอน (นำเครื่องหมาย -- ออก และใส่อีเมลของคุณเมื่อสมัครสมาชิกแล้ว)
-- ==============================================================================
-- INSERT INTO public.teachers (user_id)
-- SELECT id FROM auth.users WHERE email = 'teacher@banpladuk.ac.th';