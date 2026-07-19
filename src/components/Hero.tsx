import { ArrowRight, BellRinging, ChatCircleText, Microphone, PhoneCall } from '@phosphor-icons/react'
import { CharacterMarks } from './VisualMockups'
import { PhonePreview } from './PhonePreview'

export function Hero() {
  return (
    <section id="top" className="hero-section">
      <div className="hero-grid page-container">
        <div className="hero-copy reveal">
          <p className="section-kicker">divie.site</p>
          <CharacterMarks />
          <h1>
            DiVie giúp bạn <span className="highlight-pill">chăm sóc</span> ba mẹ từ xa, bằng
            giọng nói và AI
          </h1>
          <p className="hero-lead">
            Theo dõi sức khỏe, liên lạc và nhận cảnh báo đúng lúc trong một ứng dụng dễ dùng.
          </p>
          <div className="hero-actions" aria-label="Hành động chính">
            <a className="button button-primary" href="#demo">
              Xem demo
              <ArrowRight size={18} weight="bold" />
            </a>
            <a className="button button-secondary" href="#giai-phap">
              Tìm hiểu giải pháp
            </a>
          </div>
        </div>

        <div className="hero-visual reveal delay-1">
          <PhonePreview />
        </div>
      </div>

      <div className="hero-proof page-container" aria-label="Các điểm nổi bật">
        <div>
          <Microphone size={22} weight="duotone" />
          <span>Thao tác bằng giọng nói</span>
        </div>
        <div>
          <PhoneCall size={22} weight="duotone" />
          <span>Gọi điện qua Android</span>
        </div>
        <div>
          <ChatCircleText size={22} weight="duotone" />
          <span>Chat realtime</span>
        </div>
        <div>
          <BellRinging size={22} weight="duotone" />
          <span>Cảnh báo cho người thân</span>
        </div>
      </div>
    </section>
  )
}
