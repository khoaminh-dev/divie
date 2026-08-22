import { Cloud, Database, DeviceMobile, Globe, Lightning, PlugsConnected } from '@phosphor-icons/react'
import { techStack } from '../data/content'

const techIcons = [DeviceMobile, Globe, PlugsConnected, Database, Lightning, Cloud]

export function TechSection() {
  return (
    <section id="cong-nghe" className="section tech-section">
      <div className="page-container">
        <div className="section-heading">
          <h2>Kiến trúc gọn nhẹ, đủ realtime, tối ưu chi phí triển khai</h2>
          <p>
            Landing page, web admin và API chạy trên Vercel. App Android kết nối Firebase
            cho realtime chat, dữ liệu và thông báo.
          </p>
        </div>

        <div className="architecture">
          <div className="arch-node domain">divie.site</div>
          <div className="arch-line" />
          <div className="arch-row">
            <div className="arch-node">Vercel</div>
            <div className="arch-node">Android App</div>
          </div>
          <div className="arch-line" />
          <div className="arch-row wide">
            <div className="arch-node">Node.js API</div>
            <div className="arch-node">Firebase</div>
            <div className="arch-node">Groq AI</div>
          </div>
        </div>

        <div className="tech-grid">
          {techStack.map((tech, index) => {
            const Icon = techIcons[index]
            return (
              <article className="tech-card" key={tech.name}>
                <Icon size={25} weight="duotone" />
                <h3>{tech.name}</h3>
                <p>{tech.detail}</p>
              </article>
            )
          })}
        </div>
      </div>
    </section>
  )
}
