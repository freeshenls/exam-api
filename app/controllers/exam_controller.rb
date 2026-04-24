class ExamController < ApplicationController
  # 必须跳过 CSRF 校验（如果你是通过 API 或者简单的异步按钮调用）
  skip_before_action :verify_authenticity_token, only: [:run_exam]

  def index
		@students = Student.all
	end

  def run_exam
    # 1. 锁定学生
    @student = Student.find(params[:id])

    # 2. 核心动作：touch 会更新 updated_at。
    # 因为我们在 Student Model 里写了 after_update_commit，
    # 这一步会自动触发 WebSocket 广播，页面上的按钮会瞬间变灰（进入冷却中状态）。
    @student.touch

    # 3. 异步启动考试任务
    # 将耗时的“登录-取题-AI识别-答题”逻辑丢进后台
    ExamJob.perform_later(@student.id, 12)
    ExamJob.perform_later(@student.id, 13)
    ExamJob.perform_later(@student.id, 14)
    ExamJob.perform_later(@student.id, 15)

    # 4. 返回 204 No Content
    # 因为有 turbo_stream_from，页面会自动等待 Model 的下一次广播来更新分数
    head :no_content
  end
end