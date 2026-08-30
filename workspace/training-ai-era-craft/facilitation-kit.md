# Working session — "Code rẻ rồi, 'đúng' vẫn đắt: việc của mình dịch đi đâu?"

> Đối tượng: AE kỹ thuật nhiều năm kinh nghiệm, dùng AI hằng ngày.
> Định dạng: **working session 90', AE là tác giả — không phải training, không giảng.**
> Người điều phối (mày) nói < 20% thời gian: đặt câu hỏi, ghi bảng, ép hội tụ.
> Output cuối: **1 trang "engineering bar" do chính AE viết.**

---

## Luận điểm (xương sống cả buổi)

> AI kéo chi phí **viết** code về gần 0. Chi phí **chắc chắn nó đúng** thì không đổi.
> Cái rẻ đi nhiều nhất lại là **"code sai mà trông đúng"**.
> ⇒ Đòn bẩy của kỹ sư senior dịch từ *làm được không* sang *nhận ra lúc nào nó sai tinh vi*, và *giữ hệ thống còn mạch lạc khi generate quá rẻ*.
> Thói quen review/ownership của đội **chưa đuổi kịp** cú dịch đó. Buổi này để đội tự vá.

Đây không phải bài "AI ngu" hay "AI thần thánh". Là: **năng suất tăng, lưới an toàn chưa tăng theo** — và lưới đó đang phụ thuộc vào phản xạ của một vài người tỉnh táo.

---

## Pre-work — gửi AE trước 2-3 ngày (paste thẳng)

> AE ơi, tuần sau mình có 90' ngồi với nhau về một thứ: **AI giờ viết code nhanh, nhưng "biết chắc nó đúng" vẫn đắt như cũ.**
>
> Nhờ mỗi người mang **đúng 1 ca thật trong ~1 tháng gần đây**: một lần AI (hoặc chính mình, hoặc review sót) ra một thứ **trông đúng, đi được khá xa, rồi mới lòi ra sai tinh vi** — bug, fix sai nghiệp vụ, gãy CI, suýt sự cố prod... gì cũng được. Viết 1 đoạn ngắn: *nó trông đúng nhờ đâu, sai ở đâu, cái gì mới bắt được.*
>
> **Không phải để bóc phốt ai** — để mổ cơ chế. Tao mang ca của tao trước.

(Mục đích: mồi sẵn tư duy + đảm bảo vật liệu là của AE, không phải mày giảng. Senior nghe case của đồng nghiệp thì tin; nghe slide lý thuyết thì cười.)

---

## Run of show (90')

### 0. Khung & luật chơi (5')
- Đây là working session, không phải training. Cuối buổi ra **1 trang bar do AE viết**.
- Luật: mổ cơ chế, không bóc phốt. Mọi phần kết bằng **một quyết định AE sở hữu**, không phải một slide.

### 1. Provocation (15')
Đặt luận điểm, rồi chiếu **2-3 exhibit thật** (ẩn danh — xem mục "Seed cases"). Mục tiêu duy nhất: cả phòng gật *"ừ, đúng là tụi mình"*. Đừng giải, chỉ để nó cấn.
- Mở bằng **case của chính mày** trước (cert "đó là giả" hoặc AVM gãy CI) → tự nhận mình dính → mở khóa phòng.

### 2. Mổ vòng tròn (30')
Mỗi người 1 ca (thiếu thì lấy seed). Chạy qua **3 câu hỏi cố định**, timebox 3-4'/ca, **không sửa lỗi tại chỗ — chỉ rút pattern**:
1. Nó **trông đúng** nhờ cái gì? (giọng AI tự tin / compile được / qua happy-path / khớp mental model hiển nhiên)
2. Nó **thật ra sai** ở đâu — và **ai/cái gì** mới bắt được? (phản xạ một senior? test? CI? sự cố prod?)
3. Cái gì lẽ ra bắt được **sớm hơn và KHÔNG cần một người cụ thể**?

→ Mày ghi **riêng cột 3** lên bảng. Cột 3 chính là nguyên liệu viết bar.

### 3. AE tự viết "bar" (30')
Gom cột 3 thành ~4-6 chuẩn. Đưa **bản strawman** (mục dưới) để AE bắn — senior hội tụ nhanh hơn khi có cái để cãi, chậm khi nhìn trang trắng.
- Mỗi dòng quyết: **giữ / bỏ / sửa chữ**.
- Mỗi dòng **gán 1 owner**.
- Ép: *"cái nào không ai cãi thì chốt; cái nào cãi thì 2 phút quyết hoặc bỏ."*
- Trần cứng: **≤ 6 dòng, mỗi dòng ngày mai dùng được.**

### 4. Chốt & sở hữu (10')
- Đọc lại bar 1 trang, mỗi dòng có owner.
- Chốt nó sống ở đâu (wiki) + lịch review lại sau 2 tuần.
- (Tùy chọn) 1 người xung phong seed doc "cạnh sắc hệ thống" → cầu nối sang buổi sau.

---

## Strawman "engineering bar" (đưa AE bắn — KHÔNG phải kết luận)

Đây là mồi để AE sửa/bỏ/thêm, không phải luật áp xuống:

1. **"Done" = compile + test pass + commit đúng branch + tao trỏ được bằng chứng.** Build đỏ không bao giờ là "lỗi có sẵn".
2. **AI khẳng định root cause / "đã xong" → bắt nó trỏ đúng `file:line` / log line.** Không bằng chứng = chưa xong.
3. **Thay đổi (AI viết) chạm [data prod / tiền / state-machine / migration / auth] phải có người thứ hai đọc thật** — không rubber-stamp.
4. **Field/state dẫn xuất (DMN, derived) không sửa trực tiếp.** Và "bẫy hệ thống" kiểu này nằm trong doc/CLAUDE.md, không nằm trong đầu một người.
5. **Không dán secret/PII sống (cookie, JWT, CCCD, STK) vào AI.** Token ngắn hạn, creds ra khỏi git.
6. *(AE tự thêm — chừa chỗ này)*

---

## Seed cases (ẩn danh, sẵn để chiếu)

### Case 1 — "AI tự tin nhưng tự mâu thuẫn" (status dẫn xuất)
- **Trông đúng:** AI đề xuất gửi `status: CANCEL` để hủy cọc một booking. Curl gọn gàng, đọc cực hợp lý.
- **Thật ra sai:** `status` do **Camunda DMN tính lại** từ (paymentStatus, approvalStatus, agreementStatus, bookingType). Gửi `status` **vô tác dụng**; gửi sai input khác còn ra trạng thái bậy. AI *có* nhắc tới DMN trong câu trả lời mà **vẫn** khuyên set tay — tự mâu thuẫn.
- **Cái gì bắt được:** hai chữ *"chắc chưa"* của một người. Không phải test, không phải hệ thống.
- **Hạt giống cho bar:** độ tự tin của AI **không tương quan** với độ đúng; nó có thể cãi chính context của nó. → dòng #2, #4.

### Case 2 — "Done" giả (gãy CI vì file untracked)
- **Trông đúng:** AI viết xong feature, tuyên bố *"Tất cả thay đổi đúng"*, liệt kê file. `mvn compile` local fail thì AI **tự phủi là "lỗi Lombok/JDK17 có sẵn"**.
- **Thật ra sai:** 3 file mới **chưa `git add`** → commit thiếu → **CI đỏ** `cannot find symbol`. Mất ~8 lượt cứu (rối branch, "checkout lại mất file", "amend xử lý đi").
- **Cái gì bắt được:** log CI từ xa — *sau khi* đã merge. Lẽ ra `git status` một dòng bắt được tại chỗ.
- **Hạt giống cho bar:** "done" tuyên bố trước khi verify; build đỏ bị hợp lý hóa. → dòng #1.

### Case 3 — "6 tiếng tin một cái UI nói dối" (option, dùng để cười + điểm sâu)
- **Trông đúng:** AI đào một tác vụ GUI nó **không nhìn thấy**, liên tục báo "🎉 xong / found it" theo chữ trên màn hình.
- **Thật ra sai:** `profiles.xml` luôn rỗng — chưa lần nào thật sự xong. AI tự thú cuối buổi: *"chỗ 'nãy còn qua bước tiếp' — đó là giả... mình tưởng tiến triển nên đào tiếp."* Lối thoát đúng (làm trên máy khác, 15') có từ sớm.
- **Điểm sâu cho senior:** nó **có** ground-truth check (`find *.p12`) mà vẫn báo tiến triển *trước* khi check. Tin tín hiệu thành công giả thay vì bằng chứng.
- **Hạt giống cho bar:** → dòng #1, #2.

> Mấy ca này là thật trong lịch sử của đội/mày, đã lọc PII. Nếu AE mang đủ ca của họ thì seed chỉ cần 1-2 cái mồi.

---

## Ghi chú điều phối — phòng toàn senior (phần quyết định buổi sống hay chết)

- **Đừng giảng.** Mày < 20% thời gian. Vai trò: hỏi, ghi bảng, ép hội tụ.
- **Mở bằng case của chính mày** → tự nhận dính trước → không ai sợ bị phán.
- **Nguy cơ 1 — thành buổi than "AI ngu":** luôn kéo về **cột 3** (cái gì *systemic* bắt được). Hướng giải pháp, không đổ lỗi công cụ.
- **Nguy cơ 2 — tranh luận triết học vô tận:** timebox cứng, có chuông. 3-4'/ca, hết giờ là chuyển.
- **Nguy cơ 3 — ra list 20 luật không ai theo:** ép ≤ 6 dòng, mỗi dòng có owner, mỗi dòng "ngày mai dùng được".
- **Senior thích quyết, không thích nghe:** mọi phần kết bằng một quyết định họ sở hữu.

## Vì sao buổi này "đủ cần cho AE"
- Coi họ là **tác giả của chuẩn**, không phải học viên.
- Vật liệu là **thất bại thật của chính đội** → đáng tin, không generic.
- Luận điểm là **frontier chưa ai giải xong** → đúng tầm.
- Output là thứ họ **sẽ theo vì chính họ viết ra**.
