import { Question, Quotes } from '@phosphor-icons/react'

export function ResearchInsight() {
  return (
    <section className="section insight-section">
      <div className="page-container insight-panel">
        <div className="insight-icon">
          <Question size={34} weight="duotone" />
        </div>
        <div>
          <h2>Không phải người cao tuổi không cần giúp đỡ. Họ chỉ không muốn làm phiền.</h2>
          <p>
            DiVie bắt đầu từ câu hỏi: nếu sức khỏe của ba mẹ chuyển biến xấu, ai sẽ biết,
            biết bằng cách nào và biết có kịp không?
          </p>
        </div>
        <blockquote>
          <Quotes size={24} weight="fill" />
          <span>
            Giải pháp cần đủ đơn giản để người lớn tuổi dùng được, và đủ rõ ràng để người thân
            ở xa kịp quan tâm.
          </span>
        </blockquote>
      </div>
    </section>
  )
}
