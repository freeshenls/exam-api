class ExamsController < ApplicationController
  # 必须跳过 CSRF 校验（如果你是通过 API 或者简单的异步按钮调用）
  skip_before_action :verify_authenticity_token, only: [:run_exam, :submit_exam]

  def run_exam
    # 1. 锁定学生
    @student = Student.find(params[:id])

    # 2. 核心动作：touch 会更新 updated_at。
    # 因为我们在 Student Model 里写了 after_update_commit，
    # 这一步会自动触发 WebSocket 广播，页面上的按钮会瞬间变灰（进入冷却中状态）。
    @student.touch

    # 3. 异步启动考试任务
    # 将耗时的“登录-取题-AI识别-答题”逻辑丢进后台
    # student.touch
    ExamJob.perform_later(@student.id, "15f22328481f4fdab9958f50cc2ff575")
    ExamJob.perform_later(@student.id, "3c5cfa90841b467d96a666a1e7a656b3")
    ExamJob.perform_later(@student.id, "df7a5b1d992e4c4a85165a8d2ef77489")
    ExamJob.perform_later(@student.id, "f0cbba2c86834c62aed37be7ccb0f1d6")

    # 4. 返回 204 No Content
    # 因为有 turbo_stream_from，页面会自动等待 Model 的下一次广播来更新分数
    head :no_content
  end

  def submit_exam
    @student = Student.find(params[:id])
    
    if @student
      # 1. 扫描数据库中所有非空的 recordId
      # 对应字段：law_record, math_record, chinese_record, social_record
      records = [
        @student.law_record, 
        @student.math_record, 
        @student.chinese_record, 
        @student.social_record
      ].compact.reject(&:empty?)

      if records.any?
        conn = Faraday.new(url: "http://cj.nbjyzx.net:10000") do |f|
          f.request :url_encoded
          f.adapter Faraday.default_adapter
        end

        # 2. 批量提交所有找到的记录
        records.each do |rid|
          conn.post("/stuCurUser/submitExamOfficial") do |req|
            req.headers['Cookie'] = @student.cookie
            req.headers['X-Requested-With'] = "XMLHttpRequest"
            req.body = { recordId: rid }
          end
          puts "📤 [#{@student.username}] 已从数据库读取并提交记录: #{rid}"
        end

        # 3. 统一等待结算并同步分数
        # sync_exams! 执行后，如果远程已结项，这些字段会被清空，从而让前端按钮消失
        sleep 5
        @student.sync_exams!
      end

      head :no_content
    else
      head :bad_request
    end
  end
end
