# LiquidGlassBar 1.4.0

Thanh tab bar kiểu **Liquid Glass trong suốt cho Messenger** (iOS 15 – 16+, hỗ trợ Rootful / Rootless / RootHide).

## Điểm mới ở bản 1.4.0
- **Kính tối trong suốt & khúc xạ nền:** Sử dụng `UIBlurEffectStyleSystemUltraThinMaterialDark` kết hợp viền sáng specular mỏng, đồng thời mở rộng khung danh sách chat chạy xuyên xuống dưới thanh bar để nhìn xuyên qua và thấy hiệu ứng làm mờ nội dung khi cuộn hoặc lướt glass.
- **Ôm trọn cả icon lẫn chữ:** Tự động mở rộng chiều cao viên thuốc nền (`60pt`) và căn tâm chuẩn theo cột tab, loại trừ hoàn toàn cục thông báo đỏ (`30+`) khỏi phép đo kích thước để không bị lệch.
- **Kéo trượt mượt & chuyển tab đồng bộ:** Khóa xung đột cập nhật layout trong lúc lò xo thả tay, hỗ trợ cả `UITabBar` chuẩn lẫn thanh tab tự chế của Messenger.
- **Ăn thông số tức thì:** Đồng bộ `CFPreferencesAppSynchronize` ngay lập tức khi đổi màu, kích thước hoặc độ nảy trong Cài đặt.
- **Khung Preview tương tác trực tiếp:** Có thể chạm và kéo thử cục glass ngay trong trang Cài đặt.

## Cấu trúc thư mục
- `.github/workflows/build.yml`: Workflow GitHub Actions biên dịch 3 bản `rootful`, `rootless`, `roothide`.
- `tweak/`: Mã nguồn tweak (`Tweak.x`, `Makefile`, `LiquidGlassBar.plist`).
- `prefs/`: Bundle Cài đặt (`LGCRootListController`, `LGCPreviewCell`, `LGCColorCell`, `entry.plist`, `Resources/Root.plist`, `Resources/Info.plist`).
