# YearHeart + ADA Partners iPad — GitHub Actions starter

**สถานะ: source และ workflow เตรียมแล้ว ยังไม่ได้รัน Xcode / GitHub Actions และยังไม่มี IPA ที่ build ผ่านหรือลงนามแล้ว** เครื่องที่จัดทำเป็น Windows ไม่มี Xcode และผู้ใช้ยังไม่มี repository หรือเครื่อง Mac

## เริ่มจาก Windows โดยไม่ใช้บัญชี Apple

1. สร้าง GitHub repository แบบ Private ของคุณ เปิดใช้ Actions
2. แตก ZIP นี้ แล้วอัปโหลดไฟล์ในโฟลเดอร์เข้า root ของ repository ต้องรวม `.github/workflows/ipad.yml` ด้วย (ไฟล์ซ่อนอาจไม่ปรากฏในบางโปรแกรม)
3. ไป Actions > iPad build > Run workflow เลือก YearHeart หรือ ADAPartners และ mode `simulator`
4. รอ build เสร็จแล้วดาวน์โหลด artifact หาก build ล้มเหลวส่งลิงก์ run หรือ log ที่ไม่มีข้อมูลลับกลับมาเพื่อแก้ไข

Simulator artifact เป็น `.app` สำหรับ Simulator **ติดตั้งลง iPad จริงไม่ได้** GitHub macOS runner อาจมีค่าใช้จ่ายตามสิทธิ์/โควตาบัญชี ตรวจ billing ของคุณก่อนกดรัน งานเริ่มด้วย manual dispatch เท่านั้น ไม่มี push/PR trigger

## สร้าง IPA สำหรับ TestFlight

ต้องมี Apple Developer Program, App IDs สองรายการ, Apple Distribution certificate พร้อม private key (`.p12`) และ App Store distribution provisioning profile ที่ตรงกับแต่ละ Bundle ID ผู้ใช้ต้องจัดทำและจัดการ signing ผ่านเครื่องมือ Apple/Mac ที่เชื่อถือได้ การมี workflow ไม่ได้สร้าง certificate ให้เอง

Settings > Secrets and variables > Actions:

Variables:

| ชื่อ | ค่า |
|---|---|
| APPLE_TEAM_ID | Team ID ของคุณ |
| YEARHEART_BUNDLE_ID | Bundle ID จริงของ YearHeart |
| ADA_BUNDLE_ID | Bundle ID จริงของ ADA |

Secrets:

| ชื่อ | ค่า |
|---|---|
| APPLE_CERTIFICATE_P12_BASE64 | .p12 แบบ Base64 |
| APPLE_CERTIFICATE_PASSWORD | รหัสผ่าน .p12 |
| YEARHEART_PROFILE_BASE64 | App Store profile ของ YearHeart แบบ Base64 |
| ADA_PROFILE_BASE64 | App Store profile ของ ADA แบบ Base64 |

ไม่ส่ง private key/password ผ่านแชท ไม่ commit ไฟล์ลง repository ใช้ GitHub Secrets โดยตรง Base64 เป็น encoding ไม่ใช่ encryption

เลือก mode `signed-ipa` แล้วดาวน์โหลด IPA จาก artifact Workflow จะไม่ส่งเข้า App Store Connect หรือเผยแพร่ให้อัตโนมัติ **IPA ชนิด App Store ใช้ติดตั้งโดยแตะไฟล์บน iPad ไม่ได้** ต้องอัปโหลดผ่านช่องทาง Apple เพื่อ TestFlight และดำเนินการตรวจ beta ตามที่ Apple กำหนด ขั้นตอน upload ยังไม่รวมใน starter นี้

## ขอบเขตแอป

- สอง targets ใช้ WKWebView และ website data store แยกตาม app sandbox เปิดเว็บจริงของแต่ละบริการ
- ปุ่มย้อนกลับ/ถัดไป/รีเฟรช/หน้าแรก แชร์ลิงก์ผ่าน iPad popover ล้าง session หลังยืนยัน
- รองรับ HTTPS redirect ข้ามโดเมนและ popup ด้วย configuration ที่เว็บส่งมา ไม่เพิ่ม native JavaScript bridge หรือข้าม TLS
- ไอคอนใช้ YearHeart แบบที่เลือก และโลโก้ ADA ที่ผู้ใช้แนบมา แปลงเป็น AppIcon สำหรับ iPad โดยไม่สร้างแบรนด์ใหม่
- Target iPadOS 16 ขึ้นไป รองรับ portrait/landscape ยังไม่ได้ตรวจ Split View, device safe-area, popup/fullscreen, SSO/MFA, file picker และ media บนเครื่องจริง

ยังไม่ครบ: native download/export สำหรับ blob และไฟล์ authenticated, download progress/share downloaded files, full-screen video handling, password Autofill/credential policy, post-login account UAT, การ logout ฝั่ง server และ upload TestFlight ไม่ควรถือว่า starter นี้ใช้แทน Windows release ได้ทันที การทดสอบจริงต้องใช้บัญชีที่อนุญาตและไม่ส่งธุรกรรมจริงโดยไม่อนุมัติ

Apple อาจไม่อนุมัติแอปที่เป็นเพียงเว็บครอบ และอาจต้องมีหลักฐานสิทธิ์สำหรับบริการ/แบรนด์ภายนอก โดยเฉพาะ ADA ไม่มีการรับประกันผ่าน App Review/TestFlight

## Build บน Mac ภายหลัง

ติดตั้ง Xcode และ XcodeGen (`brew install xcodegen`) รัน `xcodegen generate` เปิด PartnerApps.xcodeproj แล้วเลือก target ที่ต้องการ Bundle IDs เริ่มต้นเป็น placeholder เปลี่ยนก่อน signing ตัว workflow ใช้ macos-15 และ Xcode default ของ runner ซึ่งเปลี่ยนได้ ตรวจ SDK ที่ Apple ยอมรับก่อนส่ง TestFlight

อ้างอิง: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/ , https://developer.apple.com/testflight/ , https://developer.apple.com/app-store/review/guidelines/ , https://github.com/actions/runner-images
