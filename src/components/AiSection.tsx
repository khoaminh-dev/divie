import { Brain, CheckCircle, XCircle } from '@phosphor-icons/react'
import { aiCapabilities } from '../data/content'
import { AiNotebookMockup } from './VisualMockups'

const avoidClaims = [
  'Không ghi AI chẩn đoán bệnh.',
  'Không kết luận người dùng mắc bệnh cụ thể.',
  'Không thay thế bác sĩ hoặc tư vấn y tế chuyên môn.',
]

export function AiSection() {
  return (
    <section className="section ai-section">
      <div className="page-container ai-grid">
        <div className="ai-copy">
          <div className="ai-badge">
            <Brain size={22} weight="duotone" />
            Groq AI
          </div>
          <h2>AI hỗ trợ phân tích xu hướng, không thay thế bác sĩ</h2>
          <p>
            DiVie dùng AI để đọc dữ liệu sức khỏe theo thời gian, tóm tắt tình trạng và tạo
            cảnh báo dễ hiểu cho người thân.
          </p>
        </div>

        <div className="ai-image-wrap">
          <AiNotebookMockup />
        </div>

        <div className="ai-lists">
          <div className="claim-list positive">
            <h3>Nên truyền thông</h3>
            {aiCapabilities.map((item) => (
              <p key={item}>
                <CheckCircle size={18} weight="fill" />
                {item}
              </p>
            ))}
          </div>
          <div className="claim-list negative">
            <h3>Không nên claim</h3>
            {avoidClaims.map((item) => (
              <p key={item}>
                <XCircle size={18} weight="fill" />
                {item}
              </p>
            ))}
          </div>
        </div>
      </div>
    </section>
  )
}
