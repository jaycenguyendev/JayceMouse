import Foundation
import JayceMouseCore

/// Interface language. English text is the key; Vietnamese comes from the table below.
/// Set from AppModel whenever the config changes; screens rebuild through RootView's `.id(language)`.
enum L10n {
    static var language: AppLanguage = .english

    static let vietnamese: [String: String] = [
        // Navigation and status
        "Overview": "Tổng quan",
        "Buttons": "Nút bấm",
        "Scrolling": "Cuộn",
        "Pointer": "Con trỏ",
        "General": "Chung",
        "About": "Giới thiệu",
        "Active": "Đang hoạt động",
        "Needs access": "Cần cấp quyền",
        "Open %@ and switch JayceMouse on.": "Mở %@ và bật JayceMouse.",

        // Overview
        "Smooth Scrolling": "Cuộn mượt",
        "Button Actions": "Hành động nút",
        "Reverse Scroll": "Đảo chiều cuộn",
        "Direct": "Trực tiếp",
        "Reversed": "Đã đảo",
        "Follows system": "Theo hệ thống",
        "%@ remaps": "%@ tuỳ chỉnh",
        "Your mouse, supercharged.": "Chuột của bạn, mạnh mẽ hơn.",
        "One step to get started.": "Chỉ một bước để bắt đầu.",
        "Smooth scrolling, trackpad-style gestures and fully custom buttons — working system-wide. Press any button on your mouse to see it light up.":
            "Cuộn mượt, cử chỉ kiểu trackpad và nút bấm tuỳ chỉnh hoàn toàn — hoạt động trên toàn hệ thống. Nhấn một nút bất kỳ trên chuột để thấy nó sáng lên.",
        "JayceMouse needs Accessibility access to read your mouse and add smooth scrolling and button actions.":
            "JayceMouse cần quyền Trợ năng (Accessibility) để đọc chuột và thêm cuộn mượt cùng các hành động nút.",
        "Customize Buttons": "Tuỳ chỉnh nút",
        "Tune Scrolling": "Chỉnh cuộn",
        "Allow Accessibility access": "Cho phép quyền Trợ năng",
        "Open %@ and switch JayceMouse on. This page updates automatically.": "Mở %@ và bật JayceMouse. Trang này sẽ tự cập nhật.",
        "Grant Access": "Cấp quyền",
        "Live activity": "Hoạt động trực tiếp",
        "Listening": "Đang lắng nghe",
        "Idle": "Đang nghỉ",
        "Move, click or scroll with your mouse and events will show up here.": "Di chuyển, nhấn hoặc cuộn chuột, các sự kiện sẽ hiện ở đây.",
        "%@ pressed": "Đã nhấn %@",
        "Scroll": "Cuộn",
        "Drag started": "Bắt đầu kéo",

        // Buttons page
        "Give every extra button its own click, double click, hold, drag or scroll action.":
            "Gán cho mỗi nút phụ hành động riêng khi nhấn, nhấn đúp, giữ, kéo hoặc cuộn.",
        "Presets": "Mẫu có sẵn",
        "3-button mouse": "Chuột 3 nút",
        "5-button mouse": "Chuột 5 nút",
        "Clear all": "Xoá tất cả",
        "Add Action": "Thêm hành động",
        "Press any button to see it light up": "Nhấn một nút bất kỳ để thấy nó sáng lên",
        "Left and right clicks are never remapped on their own — use them as a modifier with a held side button if you want to extend them.":
            "Nút trái và phải không bao giờ bị đổi chức năng khi dùng riêng — hãy dùng chúng kèm một nút phụ đang giữ nếu muốn mở rộng.",
        "No actions yet": "Chưa có hành động nào",
        "Add an action or start from a preset.": "Thêm một hành động hoặc bắt đầu từ mẫu có sẵn.",
        "hold %@": "giữ %@",
        "New Action": "Hành động mới",
        "Edit Action": "Sửa hành động",
        "Choose a button": "Chọn nút",
        "Choose a trigger": "Chọn cách kích hoạt",
        "Add modifiers (optional)": "Thêm phím bổ trợ (tuỳ chọn)",
        "Choose an action": "Chọn hành động",
        "Cancel": "Huỷ",
        "Save Action": "Lưu hành động",
        "Press a button on your mouse…": "Nhấn một nút trên chuột…",
        "Side, middle or extra buttons only.": "Chỉ nút bên, nút giữa hoặc nút phụ.",
        "Grant Accessibility access first so JayceMouse can see your mouse.": "Hãy cấp quyền Trợ năng trước để JayceMouse nhận được chuột.",
        "No button selected": "Chưa chọn nút",
        "Detect Button": "Nhận diện nút",
        "Detect Again": "Nhận diện lại",
        "Pick manually": "Chọn thủ công",
        "Keyboard": "Bàn phím",
        "Hold button": "Giữ nút",
        "None": "Không",
        "Keyboard shortcut": "Phím tắt",
        "Press a shortcut…": "Nhấn tổ hợp phím…",
        "Record shortcut": "Ghi phím tắt",
        "⌃ Control": "⌃ Control",
        "⌥ Option": "⌥ Option",
        "⇧ Shift": "⇧ Shift",
        "⌘ Command": "⌘ Command",

        // Triggers
        "Click": "Nhấn",
        "Double Click": "Nhấn đúp",
        "Triple Click": "Nhấn ba lần",
        "Hold": "Giữ",
        "Click & Drag": "Nhấn & kéo",
        "Click & Scroll": "Nhấn & cuộn",

        // Buttons and keys
        "Left Button": "Nút trái",
        "Right Button": "Nút phải",
        "Middle Button": "Nút giữa",
        "Button %@": "Nút %@",
        "Middle Click": "Nhấn nút giữa",
        "Button %@ Click": "Nhấn nút %@",
        "Key %@": "Phím %@",

        // Action groups
        "Gestures": "Cử chỉ",
        "While scrolling": "Khi cuộn",
        "macOS": "macOS",
        "Spaces": "Spaces",
        "Navigation": "Điều hướng",
        "Media & Display": "Đa phương tiện & màn hình",
        "Mouse": "Chuột",

        // Actions
        "Mission Control": "Mission Control",
        "App Exposé": "App Exposé",
        "Show Desktop": "Hiện màn hình nền",
        "Spotlight": "Spotlight",
        "Look Up & Data Detectors": "Tra cứu & nhận diện dữ liệu",
        "App Switcher": "Chuyển ứng dụng",
        "Move Left a Space": "Sang Space bên trái",
        "Move Right a Space": "Sang Space bên phải",
        "Launchpad": "Launchpad",
        "Notification Center": "Trung tâm thông báo",
        "Do Not Disturb": "Không làm phiền",
        "Siri": "Siri",
        "Smart Zoom (experimental)": "Thu phóng thông minh (thử nghiệm)",
        "Brightness Up": "Tăng độ sáng",
        "Brightness Down": "Giảm độ sáng",
        "Volume Up": "Tăng âm lượng",
        "Volume Down": "Giảm âm lượng",
        "Mute": "Tắt tiếng",
        "Play / Pause": "Phát / Tạm dừng",
        "Next Track": "Bài tiếp theo",
        "Previous Track": "Bài trước",
        "Keyboard Backlight Up": "Tăng đèn bàn phím",
        "Keyboard Backlight Down": "Giảm đèn bàn phím",
        "Back": "Quay lại",
        "Forward": "Tiến tới",
        "Scroll & Navigate": "Cuộn & điều hướng",
        "Spaces & Mission Control": "Spaces & Mission Control",
        "Zoom": "Thu phóng",
        "Horizontal Scroll": "Cuộn ngang",
        "Quick Scroll": "Cuộn nhanh",
        "Precise Scroll": "Cuộn chính xác",
        "Switch Spaces": "Chuyển Space",
        "Switch space": "Chuyển Space",
        "Desktop & Launchpad": "Màn hình nền & Launchpad",

        // Scrolling page
        "Make a plain scroll wheel glide like a trackpad.": "Biến con lăn thường thành cuộn mượt như trackpad.",
        "Enhance scrolling": "Cải thiện cuộn",
        "Turn off to hand scrolling back to macOS.": "Tắt để trả việc cuộn lại cho macOS.",
        "Smoothness": "Độ mượt",
        "Off": "Tắt",
        "Low": "Thấp",
        "Regular": "Vừa",
        "High": "Cao",
        "Medium": "Vừa",
        "Raw scroll wheel steps, only with the speed and direction you choose.": "Cuộn từng nấc như gốc, chỉ áp dụng tốc độ và chiều bạn chọn.",
        "Short, snappy glide that stops quickly.": "Trượt ngắn, gọn và dừng nhanh.",
        "Balanced glide — comfortable for documents and the web.": "Trượt cân bằng — dễ chịu khi đọc tài liệu và lướt web.",
        "Long, silky inertia like an Apple trackpad.": "Quán tính dài, mượt như trackpad của Apple.",
        "Speed": "Tốc độ",
        "Scroll faster and the distance accelerates automatically.": "Cuộn càng nhanh thì quãng đường càng tự tăng tốc.",
        "Reverse direction": "Đảo chiều",
        "Flip the direction macOS gives the scroll wheel. Off follows your System Settings.": "Đảo chiều cuộn so với macOS. Tắt thì theo Cài đặt hệ thống.",
        "Trackpad simulation": "Giả lập trackpad",
        "Sends trackpad-style phases so apps use rubber banding and momentum.": "Gửi tín hiệu kiểu trackpad để ứng dụng có hiệu ứng nảy và quán tính.",
        "Precise by default": "Mặc định cuộn chính xác",
        "Smaller steps for detail work. Hold ⌥ Option for this on demand.": "Bước cuộn nhỏ hơn cho việc tỉ mỉ. Giữ ⌥ Option để dùng khi cần.",
        "Hold a key while scrolling": "Giữ phím khi cuộn",
        "Horizontal": "Ngang",
        "Quick": "Nhanh",
        "Precise": "Chính xác",
        "Smooth": "Mượt",
        "Try it here": "Thử ở đây",
        "Scroll with your mouse wheel": "Cuộn bằng con lăn chuột",
        "Row %@": "Dòng %@",

        // Pointer page
        "Tune how the cursor tracks your mouse.": "Chỉnh cách con trỏ đi theo chuột.",
        "Use system settings": "Dùng cài đặt hệ thống",
        "Leave pointer speed and acceleration exactly as macOS has them.": "Giữ nguyên tốc độ và gia tốc con trỏ như macOS.",
        "Sensitivity": "Độ nhạy",
        "Slow": "Chậm",
        "Fast": "Nhanh",
        "Acceleration": "Gia tốc",
        "Linear": "Tuyến tính",
        "Strong": "Mạnh",
        "Acceleration at the lowest setting makes the pointer move 1:1 with your hand. Changes apply to the system mouse speed while JayceMouse is running and are restored when you quit.":
            "Gia tốc thấp nhất giúp con trỏ di chuyển 1:1 theo tay. Thay đổi áp dụng cho tốc độ chuột của hệ thống khi JayceMouse đang chạy và được khôi phục khi thoát.",

        // General page
        "Startup, menu bar and safety switches.": "Khởi động, thanh menu và công tắc an toàn.",
        "Launch at login": "Mở khi đăng nhập",
        "Start JayceMouse automatically when you sign in.": "Tự mở JayceMouse khi bạn đăng nhập.",
        "Show menu bar icon": "Hiện biểu tượng trên thanh menu",
        "Quick access to pause features without opening the window.": "Tạm dừng nhanh các tính năng mà không cần mở cửa sổ.",
        "With the menu bar icon off, JayceMouse keeps its Dock icon so you can still open it.":
            "Khi tắt biểu tượng trên thanh menu, JayceMouse giữ biểu tượng trên Dock để bạn vẫn mở được.",
        "Show mouse battery": "Hiện pin chuột",
        "Shows the battery % of your Bluetooth mouse at the top of the menu bar menu.":
            "Hiện % pin của chuột Bluetooth ở đầu menu trên thanh menu.",
        "Show keyboard battery": "Hiện pin bàn phím",
        "Shows the battery % of your Bluetooth keyboard at the top of the menu bar menu.":
            "Hiện % pin của bàn phím Bluetooth ở đầu menu trên thanh menu.",
        "Whether a device shows up depends on the device: many mice do not report their battery level to macOS, so no app can read it.":
            "Có hiện được hay không tuỳ vào loại chuột: nhiều chuột không báo mức pin cho macOS, nên không ứng dụng nào đọc được.",
        "Disable button actions": "Tắt hành động nút",
        "Temporarily pass every button straight through to macOS.": "Tạm thời để macOS xử lý mọi nút như bình thường.",
        "Disable scroll enhancements": "Tắt cải thiện cuộn",
        "Temporarily hand scrolling back to macOS.": "Tạm thời trả việc cuộn lại cho macOS.",
        "Lock pointer during drag": "Khoá con trỏ khi kéo",
        "Freeze the cursor while a Click & Drag gesture is active.": "Giữ yên con trỏ trong lúc dùng cử chỉ Nhấn & kéo.",
        "Snap pointer to OK button": "Đưa con trỏ tới nút OK",
        "When a dialog asks you to confirm, move the pointer onto its OK (default) button.":
            "Khi có hộp thoại cần xác nhận, đưa con trỏ tới nút OK (nút mặc định) của nó.",
        "Test with a dialog": "Thử với hộp thoại",
        "Snap to OK test": "Thử đưa con trỏ tới OK",
        "If the feature works, the pointer is now on the OK button.": "Nếu tính năng hoạt động, con trỏ đang nằm trên nút OK.",
        "Accessibility access": "Quyền Trợ năng",
        "Granted — JayceMouse can see and adjust your mouse.": "Đã cấp — JayceMouse có thể đọc và điều chỉnh chuột.",
        "Not granted — nothing will work until you allow it.": "Chưa cấp — chưa tính năng nào hoạt động cho tới khi bạn cho phép.",
        "Open Settings": "Mở Cài đặt",
        "Reveal config file": "Hiện tệp cấu hình",
        "Reset everything…": "Đặt lại tất cả…",
        "Reset all JayceMouse settings?": "Đặt lại toàn bộ cài đặt JayceMouse?",
        "Reset": "Đặt lại",
        "Buttons, scrolling, pointer and general settings return to their defaults.": "Cài đặt nút, cuộn, con trỏ và cài đặt chung sẽ trở về mặc định.",

        // About page
        "A modern take on a great idea.": "Một cách làm hiện đại cho một ý tưởng hay.",
        "JayceMouse": "JayceMouse",
        "Version %@": "Phiên bản %@",
        "Smooth scrolling, trackpad-style gestures and fully custom buttons for any mouse.":
            "Cuộn mượt, cử chỉ kiểu trackpad và nút bấm tuỳ chỉnh hoàn toàn cho mọi loại chuột.",
        "Enjoying JayceMouse?": "Bạn thích JayceMouse?",
        "It is free and always will be. A coffee keeps the updates coming.": "Ứng dụng miễn phí và sẽ luôn miễn phí. Một ly cà phê giúp các bản cập nhật tiếp tục ra đời.",
        "Buy me a coffee": "Mời tác giả ly cà phê",
        "Acknowledgements": "Ghi nhận",
        "JayceMouse is inspired by Mac Mouse Fix by Noah Nuebling. It is an independent implementation written from scratch and shares no code or assets with it.":
            "JayceMouse lấy cảm hứng từ Mac Mouse Fix của Noah Nuebling. Đây là bản viết lại hoàn toàn độc lập, không dùng chung mã nguồn hay tài nguyên nào.",
        "Mac Mouse Fix on GitHub": "Mac Mouse Fix trên GitHub",

        // Menu bar
        "Jayce Mouse Settings…": "Cài đặt Jayce Mouse…",
        "Pause Button Actions": "Tạm dừng hành động nút",
        "Pause Scroll Enhancements": "Tạm dừng cải thiện cuộn",
        "Language": "Ngôn ngữ",
        "Quit JayceMouse": "Thoát JayceMouse",
        "Batteries": "Pin",
        "Unknown device": "Thiết bị không rõ tên",
        "Bluetooth device": "Thiết bị Bluetooth",
    ]
}

/// Translates an English interface string into the current language.
func tr(_ english: String) -> String {
    guard L10n.language == .vietnamese else { return english }
    return L10n.vietnamese[english] ?? english
}

/// Translates a string with `%@` placeholders, then fills them in.
func tr(_ english: String, _ arguments: String...) -> String {
    var text = tr(english)
    for argument in arguments {
        guard let range = text.range(of: "%@") else { break }
        text.replaceSubrange(range, with: argument)
    }
    return text
}
