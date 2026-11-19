# LiquidGlassBar 1.5.0

Thanh tab bar kiểu **Liquid Glass trong suốt cho Messenger** (iOS 15 – 16+, hỗ trợ Rootful / Rootless / RootHide).

## Điểm mới ở bản 1.5.0
- **Sửa lỗi không hiện trong Cài đặt:** Liên kết chuẩn `Preferences.framework` trong `prefs/Makefile`, khai báo `preferenceloader` trong `control` và đóng gói chuẩn `entry.plist` cho cả Rootful / Rootless / RootHide.
- **Vuốt trượt mượt mà, hết khựng giật:** Thay thế lớp blur lồng nhau gây nghẽn GPU bằng thấu kính khúc xạ specular thuần CoreAnimation kết hợp `UIPanGestureRecognizer` làm mượt vận tốc, giúp glass trượt êm và nảy tự nhiên sang tab kế tiếp.
- **Tỷ lệ viên thuốc thon gọn chuẩn iOS 26:** Viên thuốc nền cao `52pt` với lề ngang `16pt`, cục glass chọn rộng `82%` và cao `84%` ôm trọn cả icon lẫn chữ với khoảng thoáng cân đối.
