import { BellRinging, ChartLineUp, ChatsCircle, MicrophoneStage } from '@phosphor-icons/react'
import { CareBoardMockup } from './VisualMockups'

const solutionItems = [
  {
    icon: MicrophoneStage,
    title: 'Người cao tuổi nói để thao tác',
    body: 'Mở tính năng, cập nhật tình trạng và yêu cầu gọi người thân bằng giọng nói.',
  },
  {
    icon: ChartLineUp,
    title: 'Người thân xem được dữ liệu',
    body: 'Theo dõi chỉ số, biểu đồ, triệu chứng và lịch sử chăm sóc từ xa.',
  },
  {
    icon: BellRinging,
    title: 'Hệ thống cảnh báo khi cần chú ý',
    body: 'Thông báo được gửi khi có chỉ số bất thường hoặc xu hướng cần kiểm tra.',
  },
  {
    icon: ChatsCircle,
    title: 'Gia đình giữ liên lạc hằng ngày',
    body: 'Chat realtime và gọi điện nhanh giúp việc quan tâm diễn ra tự nhiên hơn.',
  },
]

export function SolutionSection() {
  return (
    <section id="giai-phap" className="section solution-section">
      <div className="page-container solution-grid">
        <div className="solution-media">
          <CareBoardMockup />
        </div>
        <div className="solution-copy">
          <h2>Một trợ lý sức khỏe đơn giản cho người lớn tuổi</h2>
          <p>
            DiVie kết hợp app Android, web admin và AI để biến việc theo dõi sức khỏe từ xa
            thành một quy trình nhẹ nhàng, có dữ liệu và có cảnh báo.
          </p>
          <div className="solution-list">
            {solutionItems.map((item) => (
              <article key={item.title}>
                <item.icon size={24} weight="duotone" />
                <div>
                  <h3>{item.title}</h3>
                  <p>{item.body}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
