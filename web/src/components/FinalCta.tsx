import { ArrowRight, Heart } from '@phosphor-icons/react'

export function FinalCta() {
  return (
    <section id="demo" className="section final-section">
      <div className="page-container final-panel">
        <Heart size={34} weight="duotone" />
        <h2>DiVie giúp sự quan tâm đến đúng lúc hơn</h2>
        <p>
          Một ứng dụng nhỏ, dễ dùng, nhưng có thể giúp gia đình theo dõi sức khỏe người thân
          rõ ràng và chủ động hơn mỗi ngày.
        </p>
        <a className="button button-primary" href="mailto:hello@divie.site">
          Liên hệ demo
          <ArrowRight size={18} weight="bold" />
        </a>
      </div>
    </section>
  )
}
