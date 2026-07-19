import {
  BellSimple,
  ChatCircleText,
  Check,
  Heartbeat,
  HouseLine,
  Microphone,
  Pill,
  TrendUp,
  UserCircle,
  Warning,
} from '@phosphor-icons/react'

const marks = [
  { label: 'Bà', src: '/characters/grandma.svg' },
  { label: 'Mẹ', src: '/characters/mother.svg' },
  { label: 'Ông', src: '/characters/grandfather.svg' },
  { label: 'Con', src: '/characters/child.svg' },
  { label: 'AI', src: '/characters/ai.svg' },
  { label: 'Bác sĩ', src: '/characters/doctor.svg' },
  { label: 'Nhà', src: '/characters/home.svg' },
]

export function CharacterMarks() {
  return (
    <div className="character-marks" aria-label="Các nhân vật trong gia đình DiVie">
      {marks.map((mark) => (
        <span className="character-mark" key={mark.label}>
          <img src={mark.src} alt={mark.label} />
        </span>
      ))}
    </div>
  )
}

export function FamilyDistanceMockup() {
  return (
    <div className="paper-visual family-distance" aria-label="Mô phỏng kết nối gia đình từ xa">
      <div className="note-line top" />
      <div className="family-map">
        <div className="home-node">
          <HouseLine size={28} weight="duotone" />
          <strong>Ba mẹ ở nhà</strong>
          <span>Huyết áp vừa cập nhật</span>
        </div>
        <div className="connection-line" />
        <div className="home-node child">
          <UserCircle size={30} weight="duotone" />
          <strong>Người thân ở xa</strong>
          <span>Nhận cảnh báo tức thì</span>
        </div>
      </div>
      <div className="mini-alerts">
        <span>
          <Warning size={16} weight="fill" />
          Chỉ số cần chú ý
        </span>
        <span>
          <ChatCircleText size={16} weight="fill" />
          Tin nhắn mới
        </span>
      </div>
    </div>
  )
}

export function CareBoardMockup() {
  const tasks = [
    { label: 'Uống thuốc sáng', status: 'Hoàn thành', tone: 'done' },
    { label: 'Đo huyết áp', status: 'Cần nhập', tone: 'todo' },
    { label: 'Gọi cho con trai', status: 'Gợi ý', tone: 'suggest' },
  ]

  return (
    <div className="paper-visual care-board" aria-label="Mô phỏng bảng chăm sóc DiVie">
      <div className="mock-window-top">
        <span />
        <span />
        <span />
      </div>
      <div className="care-board-header">
        <div>
          <strong>Hồ sơ bác Lan</strong>
          <p>Theo dõi hôm nay</p>
        </div>
        <span className="board-pill">Realtime</span>
      </div>
      <div className="task-stack">
        {tasks.map((task) => (
          <div className="task-card" key={task.label}>
            <span className={`task-status ${task.tone}`}>{task.status}</span>
            <strong>{task.label}</strong>
          </div>
        ))}
      </div>
      <div className="board-actions">
        <span>
          <Microphone size={16} weight="bold" />
          Voice
        </span>
        <span>
          <Pill size={16} weight="bold" />
          Lịch thuốc
        </span>
        <span>
          <BellSimple size={16} weight="bold" />
          Cảnh báo
        </span>
      </div>
    </div>
  )
}

export function AiNotebookMockup() {
  const rows = [
    'Nhịp tim ổn định trong 7 ngày gần nhất.',
    'Huyết áp có 2 lần cao hơn ngưỡng theo dõi.',
    'Nên nhắc người thân kiểm tra lại vào buổi tối.',
  ]

  return (
    <div className="paper-visual ai-notebook" aria-label="Mô phỏng sổ tay phân tích AI">
      <div className="ai-page-title">
        <Heartbeat size={28} weight="duotone" />
        <div>
          <strong>Tóm tắt AI</strong>
          <p>Không thay thế bác sĩ</p>
        </div>
      </div>
      <div className="trend-card">
        <TrendUp size={22} weight="duotone" />
        <strong>Xu hướng tuần này</strong>
        <span>Cần theo dõi nhẹ</span>
      </div>
      <div className="notebook-lines">
        {rows.map((row) => (
          <p key={row}>
            <Check size={16} weight="bold" />
            {row}
          </p>
        ))}
      </div>
    </div>
  )
}
