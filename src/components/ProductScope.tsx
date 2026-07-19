import { Check } from '@phosphor-icons/react'
import { productScope } from '../data/content'

export function ProductScope() {
  return (
    <section className="section scope-section">
      <div className="page-container scope-layout">
        <div>
          <h2>Bộ sản phẩm bàn giao cho đề tài</h2>
          <p>
            DiVie không chỉ là một landing page. Đây là bộ sản phẩm gồm app, admin, backend
            và tài liệu để phục vụ demo, báo cáo và phản biện.
          </p>
        </div>

        <div className="scope-list">
          {productScope.map((item) => (
            <p key={item}>
              <Check size={18} weight="bold" />
              {item}
            </p>
          ))}
        </div>
      </div>
    </section>
  )
}
