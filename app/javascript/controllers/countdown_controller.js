import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["timer", "button"]
  static values = { updatedAt: String }

  connect() {
    if (!this.hasTimerTarget) return
    this.update()
    this.timer = setInterval(() => this.update(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  update() {
    const diff = (new Date() - new Date(this.updatedAtValue)) / 1000
    const remaining = Math.max(0, 600 - diff) // 10分钟 = 600秒

    if (remaining <= 0) {
      this.finish()
      return
    }

    const m = Math.floor(remaining / 60)
    const s = Math.floor(remaining % 60)
    this.timerTarget.innerText = `冷却中 ${m}:${s.toString().padStart(2, '0')}`
  }

  finish() {
    clearInterval(this.timer)
    // 1. 隐藏倒计时文字
    this.timerTarget.style.display = "none"
    // 2. 显示按钮
    if (this.hasButtonTarget) {
      this.buttonTarget.style.display = "block"
    }
  }
}
