# Hướng dẫn cấu trúc dự án

## 1. Mục đích dự án

Đây là game minigame multiplayer. Người chơi tham gia nhiều màn chơi nhỏ, được xếp hạng sau từng màn, nhận điểm theo thứ hạng, sau đó cộng dồn điểm để xác định người chiến thắng cuối cùng.

Cấu trúc thư mục được chia theo **loại nội dung** và **trách nhiệm**, giúp dễ tìm kiếm, kiểm tra lỗi, mở rộng tính năng, làm việc nhóm và quản lý bằng Git.

---

## 2. Cấu trúc hiện tại

```text
testgame/
├── addons/
│   └── godot_ai/
├── assets/
│   ├── animations/
│   ├── audio/
│   ├── characters/
│   ├── environment/
│   ├── minigames/
│   └── ui/
├── data/
├── docs/
│   └── README_STRUCTURE.md
├── scenes/
│   ├── core/
│   ├── menus/
│   ├── minigames/
│   ├── players/
│   └── ui/
├── scripts/
│   ├── core/
│   ├── minigames/
│   ├── networking/
│   ├── players/
│   ├── systems/
│   └── ui/
├── .editorconfig
├── .gitattributes
├── .gitignore
└── project.godot
```

`.godot/` cũng tồn tại ở thư mục gốc nhưng là dữ liệu tạm do Godot tự tạo. Không chỉnh sửa thủ công, không đưa vào Git.

---

## 3. Giải thích từng thư mục

### `addons/`

Chứa plugin Godot bên thứ ba hoặc plugin nội bộ.

- `addons/godot_ai/`: plugin hỗ trợ Godot AI hiện tại.
- Không đặt script gameplay, scene minigame hoặc asset game vào đây.
- Không tự ý đổi tên hoặc di chuyển file trong plugin nếu chưa kiểm tra dependency.

### `assets/`

Chứa tài nguyên dùng trong game. Chỉ đặt tài nguyên, không đặt logic gameplay.

#### `assets/animations/`

Animation, animation library, animation resource.

Ví dụ hiện tại:

- `general_animations.res`
- `movement_animations.res`
- `KayKit_Character_Animations_1.1/`

#### `assets/audio/`

Âm nhạc, hiệu ứng âm thanh, voice, ambience.

Có thể phân loại thêm khi cần:

```text
assets/audio/
├── music/
├── sfx/
└── voice/
```

#### `assets/characters/`

Model nhân vật, texture, material, animation đi kèm nhân vật.

Ví dụ hiện tại:

- `KayKit_Adventurers_2.0_FREE/`

#### `assets/environment/`

Model bản đồ, vật thể môi trường, texture địa hình, props, skybox.

#### `assets/minigames/`

Asset chỉ dùng riêng cho từng minigame. Nên tạo thư mục con theo minigame:

```text
assets/minigames/
├── race/
├── obstacle_course/
└── reaction_test/
```

#### `assets/ui/`

Icon, hình nền menu, texture giao diện, font, button image.

### `data/`

Dữ liệu cấu hình không trực tiếp là scene hoặc script.

Có thể dùng cho:

- Danh sách minigame.
- Luật tính điểm.
- Bảng xếp hạng.
- Cấu hình thời gian mỗi màn.
- Thông tin nhân vật.
- Resource `.tres` hoặc JSON được game đọc lúc chạy.

Không đặt code xử lý vào `data/`.

### `docs/`

Tài liệu dự án.

File này mô tả cấu trúc thư mục. Các tài liệu tương lai có thể gồm:

- Quy tắc đặt tên.
- Thiết kế multiplayer.
- Luật tính điểm.
- Danh sách minigame.
- Hướng dẫn build và phát hành.
- Nhật ký thay đổi lớn.

### `scenes/`

Chứa các file scene `.tscn`, `.scn` và scene-related resource.

#### `scenes/core/`

Scene nền tảng hoặc scene điều phối cấp cao.

Hiện tại:

- `main.tscn`: scene chính được chạy từ `project.godot`.

Nên đặt tại đây các scene như bootstrap, game flow, loading hoặc world root.

#### `scenes/menus/`

Menu chính, lobby, phòng chơi, chọn minigame, kết quả trận, bảng tổng kết.

#### `scenes/minigames/`

Scene của từng minigame. Mỗi minigame nên có thư mục riêng khi đủ lớn:

```text
scenes/minigames/
├── race/
│   ├── race.tscn
│   └── checkpoints.tscn
└── obstacle_course/
    └── obstacle_course.tscn
```

#### `scenes/players/`

Scene nhân vật, player controller scene, avatar và các scene liên quan người chơi.

Hiện tại:

- `player.tscn`: scene nhân vật người chơi.

#### `scenes/ui/`

HUD, scoreboard, timer, bảng thứ hạng, popup, thông báo và thành phần giao diện dùng trong gameplay.

Hiện tại:

- `hud.tscn`: HUD hiện tại.

### `scripts/`

Chứa toàn bộ script `.gd`. Phân loại theo trách nhiệm, không gom tất cả script vào một thư mục.

#### `scripts/core/`

Luồng khởi động và điều phối cấp cao của game.

Hiện tại:

- `main.gd`: script cũ gắn với logic scene chính.

#### `scripts/minigames/`

Logic riêng của từng minigame.

Nên tổ chức theo minigame khi dự án phát triển:

```text
scripts/minigames/
├── race/
│   ├── race_manager.gd
│   └── checkpoint.gd
└── obstacle_course/
    └── obstacle_course_manager.gd
```

#### `scripts/networking/`

Multiplayer, host/client, kết nối, đồng bộ trạng thái, RPC, lobby và quản lý người chơi mạng.

Không đặt UI lobby hoặc scene minigame vào đây; chỉ đặt logic networking.

#### `scripts/players/`

Logic nhân vật, di chuyển, animation, tương tác và trạng thái người chơi.

Hiện tại:

- `player.gd`: logic điều khiển nhân vật.

#### `scripts/systems/`

Các hệ thống dùng chung toàn game.

Ví dụ:

- Quản lý vòng chơi.
- Quản lý minigame.
- Quản lý điểm.
- Xếp hạng.
- Đồng hồ trận đấu.
- Save/load.
- Audio manager.
- Scene transition.

#### `scripts/ui/`

Logic UI và HUD.

Hiện tại:

- `character_switcher.gd`: đổi nhân vật từ giao diện hiện tại.

### `project.godot`

File cấu hình chính của Godot.

Chứa:

- Tên project.
- Scene khởi động.
- Input map.
- Plugin được bật.
- Thiết lập hiển thị, vật lý và rendering.

Nên chỉnh bằng Godot Editor khi có thể.

### `.editorconfig`, `.gitattributes`, `.gitignore`

- `.editorconfig`: quy tắc format file.
- `.gitattributes`: quy tắc xử lý file trong Git.
- `.gitignore`: loại các file tạm, cache, dữ liệu máy cá nhân khỏi Git.

---

## 4. Quy tắc đặt tên

- Dùng `snake_case` cho file và thư mục: `score_manager.gd`, `main_menu.tscn`.
- Tên scene phản ánh vai trò: `player.tscn`, `scoreboard.tscn`.
- Tên script phản ánh đối tượng hoặc hệ thống: `player.gd`, `round_manager.gd`.
- Một file nên có một trách nhiệm chính.
- Không dùng tên chung chung như `test.gd`, `new_scene.tscn`, `script2.gd` cho nội dung thật.
- Tên minigame nên thống nhất giữa `assets/minigames/`, `scenes/minigames/` và `scripts/minigames/`.

---

## 5. Quy tắc thêm một minigame mới

1. Tạo asset tại `assets/minigames/<ten_minigame>/`.
2. Tạo scene tại `scenes/minigames/<ten_minigame>/`.
3. Tạo logic tại `scripts/minigames/<ten_minigame>/`.
4. Đặt dữ liệu cấu hình tại `data/` nếu cần.
5. Đăng ký minigame trong hệ thống điều phối, không sửa trực tiếp minigame khác.
6. Kiểm tra đường dẫn `res://` sau khi di chuyển hoặc đổi tên file.
7. Chạy thử project trước khi commit.

---

## 6. Quy tắc cho hệ thống điểm và xếp hạng

Logic dùng chung nên đặt tại `scripts/systems/`, không sao chép vào từng minigame.

Ví dụ phân chia:

- Minigame xác định kết quả người chơi.
- Hệ thống điểm quy đổi kết quả thành điểm.
- Hệ thống vòng chơi chuyển sang màn tiếp theo.
- Hệ thống tổng kết cộng điểm qua các màn.
- UI chỉ hiển thị dữ liệu, không tự quyết định điểm cuối cùng.

Cách này tránh tình trạng mỗi minigame có một cách tính điểm khác nhau ngoài ý muốn.

---

## 7. Quy tắc multiplayer

- Logic quyết định kết quả nên chạy ở authority/server.
- Client chỉ gửi input hoặc yêu cầu hợp lệ.
- Không tin điểm số do client tự gửi.
- Dữ liệu cần đồng bộ phải có nguồn sở hữu rõ ràng.
- UI không được là nguồn dữ liệu chính của trận đấu.
- Khi thêm RPC, ghi rõ hàm chạy ở server, client hoặc cả hai.

Chi tiết kỹ thuật multiplayer nên ghi thành tài liệu riêng trong `docs/` khi hệ thống bắt đầu triển khai.

---

## 8. Không đặt gì vào đâu?

- Không đặt file tạm, bản backup, file export vào thư mục source chính.
- Không chỉnh sửa `.godot/` thủ công.
- Không đặt asset vào `scripts/`.
- Không đặt script vào `assets/`.
- Không đặt logic dùng chung vào thư mục riêng của một minigame.
- Không tạo thư mục mới chỉ để chứa một file nếu chưa cần mở rộng.

Mục tiêu: cấu trúc rõ ràng nhưng không tạo thư mục hoặc file dư thừa.
