import {
  BellSimple,
  Camera,
  ChartBar,
  ChatCircleText,
  Microphone,
  PhoneCall,
  Pill,
  ShieldCheck,
} from '@phosphor-icons/react'
import { familyFeatures, seniorFeatures } from '../data/content'

const seniorIcons = [Microphone, PhoneCall, Camera, Pill]
const familyIcons = [ChartBar, ChatCircleText, BellSimple, ShieldCheck]

export function FeatureBento() {
  return (
    <section id="tinh-nang" className="section feature-section">
      <div className="page-container">
        <div className="section-heading narrow">
          <h2>Tính năng được chia theo đúng người dùng</h2>
          <p>
            Một phía là trải nghiệm cực dễ cho người cao tuổi, phía còn lại là bảng theo dõi
            đủ rõ cho người thân.
          </p>
        </div>

        <div className="feature-bento">
          <div className="feature-column senior">
            <div className="feature-column-head">
              <span>Cho người cao tuổi</span>
              <strong>Nói, chạm, gọi</strong>
            </div>
            {seniorFeatures.map((feature, index) => {
              const Icon = seniorIcons[index]
              return (
                <article className="feature-card" key={feature.title}>
                  <Icon size={26} weight="duotone" />
                  <h3>{feature.title}</h3>
                  <p>{feature.body}</p>
                </article>
              )
            })}
          </div>

          <div className="feature-column family">
            <div className="feature-column-head">
              <span>Cho người thân</span>
              <strong>Theo dõi, nhắc nhở, phản hồi</strong>
            </div>
            {familyFeatures.map((feature, index) => {
              const Icon = familyIcons[index]
              return (
                <article className="feature-card" key={feature.title}>
                  <Icon size={26} weight="duotone" />
                  <h3>{feature.title}</h3>
                  <p>{feature.body}</p>
                </article>
              )
            })}
          </div>
        </div>
      </div>
    </section>
  )
}
