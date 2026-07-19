export const navItems = [
  { label: 'Vấn đề', href: '#van-de' },
  { label: 'Giải pháp', href: '#giai-phap' },
  { label: 'Tính năng', href: '#tinh-nang' },
  { label: 'Công nghệ', href: '#cong-nghe' },
]

export const problemPoints = [
  'Người thân khó biết tình trạng sức khỏe hằng ngày của ba mẹ khi sống xa nhà.',
  'Người cao tuổi dễ quên nhập chỉ số hoặc thao tác sai do mắt yếu, tay run.',
  'Dấu hiệu bất thường thường chỉ được phát hiện khi tình trạng đã rõ ràng hơn.',
  'Con cháu thiếu dữ liệu dài hạn để nhìn ra xu hướng sức khỏe theo thời gian.',
]

export const seniorFeatures = [
  {
    title: 'Điều khiển bằng giọng nói',
    body: 'Người cao tuổi có thể mở tính năng, cập nhật tình trạng hoặc yêu cầu liên lạc mà không cần nhớ nhiều thao tác.',
  },
  {
    title: 'Gọi điện nhanh',
    body: 'App dùng chức năng gọi mặc định của Android để liên hệ người thân, không cần xây hệ thống gọi riêng.',
  },
  {
    title: 'Cập nhật sức khỏe',
    body: 'Ghi nhận huyết áp, nhịp tim, triệu chứng và cảm nhận trong ngày bằng thao tác đơn giản.',
  },
  {
    title: 'Nhắc uống thuốc',
    body: 'Thiết lập lịch nhắc theo giờ, theo ngày và theo hướng dẫn chăm sóc đã được người thân cấu hình.',
  },
]

export const familyFeatures = [
  {
    title: 'Theo dõi từ xa',
    body: 'Người thân xem hồ sơ sức khỏe, lịch sử chỉ số và biểu đồ theo ngày, tuần, tháng.',
  },
  {
    title: 'Chat realtime',
    body: 'Tin nhắn giữa người cao tuổi và người thân được đồng bộ realtime qua Firebase.',
  },
  {
    title: 'Cảnh báo sớm',
    body: 'Khi chỉ số vượt ngưỡng hoặc có xu hướng bất thường, hệ thống gửi thông báo để người thân kiểm tra.',
  },
  {
    title: 'Quản lý chăm sóc',
    body: 'Người thân có thể quản lý lịch uống thuốc, ghi chú, ảnh toa thuốc và nội dung nhắc nhở.',
  },
]

export const aiCapabilities = [
  'Phân tích xu hướng huyết áp, nhịp tim và triệu chứng đã ghi nhận.',
  'Gợi ý mức độ rủi ro để người thân chú ý sớm hơn.',
  'Tóm tắt tình trạng sức khỏe theo thời gian bằng ngôn ngữ dễ hiểu.',
  'Hỗ trợ nhận diện ảnh để giảm thao tác nhập liệu thủ công.',
]

export const techStack = [
  {
    name: 'React Native',
    detail: 'App Android cho người cao tuổi và người thân.',
  },
  {
    name: 'Vite React',
    detail: 'Landing page và web admin triển khai nhanh, dễ bảo trì.',
  },
  {
    name: 'Node.js',
    detail: 'API backend trên Vercel Functions để xử lý logic và bảo mật key.',
  },
  {
    name: 'Firebase',
    detail: 'Auth, Firestore, realtime chat, storage và push notification.',
  },
  {
    name: 'Groq',
    detail: 'Tích hợp AI để phân tích dữ liệu và tạo cảnh báo dễ hiểu.',
  },
  {
    name: 'Android native',
    detail: 'Gọi điện, speech-to-text và text-to-speech dùng chức năng mặc định của thiết bị.',
  },
]
