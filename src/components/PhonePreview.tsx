import {
  BellSimpleRinging,
  ChartLineUp,
  ChatCircleText,
  Heartbeat,
  Microphone,
  Pill,
  UserCircle,
} from '@phosphor-icons/react'

const records = [
  { label: 'Huyết áp', value: '132/84', tone: 'stable' },
  { label: 'Nhịp tim', value: '78 bpm', tone: 'good' },
  { label: 'Triệu chứng', value: 'Hơi chóng mặt', tone: 'watch' },
]

export function PhonePreview() {
  return (
    <div className="phone-preview" aria-label="Xem trước workspace DiVie">
      <div className="mock-window-top">
        <span />
        <span />
        <span />
      </div>

      <div className="workspace-grid">
        <aside className="workspace-sidebar">
          <strong>DiVie</strong>
          <span>Hồ sơ bác Lan</span>
          <span>Lịch uống thuốc</span>
          <span>Tin nhắn gia đình</span>
          <span>Cảnh báo AI</span>
        </aside>

        <div className="workspace-main">
          <div className="phone-top">
            <div>
              <span className="phone-greeting">Workspace chăm sóc</span>
              <strong>Hôm nay bác Lan thấy thế nào?</strong>
            </div>
            <span className="voice-chip">
              <Microphone size={16} weight="bold" />
              Voice
            </span>
          </div>

          <button className="voice-command" type="button">
            <Microphone size={22} weight="fill" />
            Nói: "Gọi con trai"
          </button>

          <div className="record-list">
            {records.map((record) => (
              <div className={`record-item ${record.tone}`} key={record.label}>
                <span>{record.label}</span>
                <strong>{record.value}</strong>
              </div>
            ))}
          </div>

          <div className="phone-actions">
            <span>
              <Heartbeat size={18} weight="duotone" />
              Cập nhật
            </span>
            <span>
              <Pill size={18} weight="duotone" />
              Thuốc
            </span>
            <span>
              <ChartLineUp size={18} weight="duotone" />
              Biểu đồ
            </span>
          </div>
        </div>

        <div className="workspace-sidepanel">
          <div className="care-person">
            <UserCircle size={34} weight="duotone" />
            <div>
              <strong>Minh Điều</strong>
              <span>Người thân</span>
            </div>
          </div>
          <div className="chat-preview">
            <ChatCircleText size={18} weight="duotone" />
            <p>Mẹ vừa cập nhật huyết áp. AI gợi ý nên kiểm tra lại buổi tối.</p>
          </div>
          <div className="alert-strip">
            <BellSimpleRinging size={18} weight="duotone" />
            AI đang theo dõi xu hướng chỉ số trong tuần.
          </div>
        </div>
      </div>
    </div>
  )
}
