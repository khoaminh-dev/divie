import { Eye, HandPalm, TrendUp, WarningCircle } from '@phosphor-icons/react'
import { problemPoints } from '../data/content'
import { FamilyDistanceMockup } from './VisualMockups'

const icons = [Eye, HandPalm, WarningCircle, TrendUp]

export function ProblemSection() {
  return (
    <section id="van-de" className="section problem-section">
      <div className="page-container problem-layout">
        <div className="problem-copy">
          <h2>Khi ba mẹ ở xa, một dấu hiệu nhỏ cũng có thể bị bỏ lỡ</h2>
          <p>
            Người trẻ đi học, đi làm xa quê thường không thể theo dõi sức khỏe ba mẹ mỗi ngày.
            Trong khi đó, người lớn tuổi lại hay ngại chia sẻ khi cơ thể có dấu hiệu bất thường.
          </p>
        </div>

        <div className="problem-media">
          <FamilyDistanceMockup />
        </div>

        <div className="problem-points">
          {problemPoints.map((point, index) => {
            const Icon = icons[index]
            return (
              <article className="problem-card" key={point}>
                <Icon size={24} weight="duotone" />
                <p>{point}</p>
              </article>
            )
          })}
        </div>
      </div>
    </section>
  )
}
