# lib/tasks/exam.rake
namespace :exam do
  desc "粘贴考试结果 JSON 自动纠正题库"
  task :run => :environment do
    puts "请直接粘贴 JSON 数据（按回车后，按 Ctrl+D 提交）："
    puts "-" * 30
    
    input_data = $stdin.read
    
    begin
      json_data = JSON.parse(input_data)
      data = json_data["data"]
      wrong_questions = data["wrongQuestions"] || []
      
      # 自动识别 paper_id
      paper_name = data["papername"]
      paper_id = case paper_name
                 when /语文/ then "12"
                 when /数学/ then "13"
                 when /法律/ then "14"
                 when /社会/ then "15"
                 else "12"
                 end

      puts "\n分析卷子: #{paper_name} (ID: #{paper_id})"
      
      updated_count = 0
      wrong_questions.each do |q|
        # 寻找对应的题目并修正答案
        record = QuestionBank.find_or_initialize_by(
          paper_id: paper_id,
          question_title: q['questiontitle']
        )
        
        record.answer = q['answer']
        
        if record.save
          updated_count += 1
          puts "[修正] #{q['questiontitle'][0..15]}... -> 答案: #{q['answer']}"
        end
      end

      puts "-" * 30
      puts "完成！#{paper_name} 题库已纠正 #{updated_count} 道错题。"
      
    rescue JSON::ParserError
      puts "错误: JSON 格式不对，检查下是不是复制漏了。"
    rescue => e
      puts "发生异常: #{e.message}"
    end
  end
end
