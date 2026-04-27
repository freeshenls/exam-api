require 'net/http'
require 'uri'

namespace :vip do
  desc "通过 HTTP 接口批量导入学生并触发 AI 登录"
  task import: :environment do
    # 配置接口地址
    uri = URI.parse("http://localhost:3000/students")
    
    # 待导入数据
    data = <<~DATA
      18857905600 182673@Crgz
    DATA

    puts "🚀 准备调用接口: #{uri}"
    
    data.strip.each_line do |line|
      username, password = line.strip.split(/\s+/)
      next if username.blank? || password.blank?

      begin
        # 发送请求
        # 因为你设置了 skip_before_action :verify_authenticity_token，所以直接 POST 即可
        response = Net::HTTP.post_form(uri, {
          "student[username]" => username,
          "student[password]" => password
        })

        if response.code.to_i.between?(200, 302)
          puts "✅ [#{username}] 接口调用成功"

          # 修正查找逻辑
          student = Student.find_by(username: username)
          
          if student
            # 依次执行四门考试（同步模式）
            # 注意：如果 ExamJob 内部有 sleep 10-15 分钟，脚本会在这里等很久
            ExamJob.perform_now(student.id, "15f22328481f4fdab9958f50cc2ff575")
            ExamJob.perform_now(student.id, "3c5cfa90841b467d96a666a1e7a656b3")
            ExamJob.perform_now(student.id, "df7a5b1d992e4c4a85165a8d2ef77489")
            ExamJob.perform_now(student.id, "f0cbba2c86834c62aed37be7ccb0f1d6")
            puts "🎊 [#{username}] 四门功课全部处理完毕"
          end
        else
          puts "❌ [#{username}] 接口返回异常: #{response.code}"
        end
      rescue => e
        puts "💥 [#{username}] 请求发生错误: #{e.message}"
      end
      
      # 稍微给点间隔，防止 AI 识别验证码并发过高
      sleep 0.5
    end

    puts "🏁 批量任务执行完毕"
  end
end
