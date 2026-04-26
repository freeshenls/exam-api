# app/jobs/exam_job.rb
class ExamJob < ApplicationJob
  queue_as :default

  def perform(student_id, paper_id)
    student = Student.find(student_id)
    @paper_id = paper_id
    return unless student.cookie.present?

    @conn = Faraday.new(url: "http://cj.nbjyzx.net:10000") do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end

    # 1. 开启考试
    record_id = start_exam(student)
    return unless record_id

    # 2. 获取题目
    questions = get_questions(student, record_id)
    return unless questions.any?

    # 3. 循环答题
    questions.each do |q|
      # 暴力扫题：库里没题就存入并默认选 A
      record = QuestionBank.find_or_create_by!(
        paper_id: @paper_id, 
        exam_question_id: q['examQuestionId']
      ) do |qb|
        qb.question_title = q['questiontitle']
        qb.answer         = "A"
      end

      # 提交答案：参数名 choice
      save_answer(student, record_id, q['id'], record.answer)
      sleep rand(0.3..0.6)
    end

    # ✅ 核心逻辑：立即同步 recordId 到数据库 (xx_record 字段)
    # 这会触发 Student 模型里的 sync_exams!，利用远程返回的 unfinishedRecordId 入库
    student.sync_exams!
  end

  private

  def start_exam(student)
    response = @conn.post("/stuCurUser/startExamOfficial") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.body = { examPaperId: @paper_id }
    end
    res = JSON.parse(response.body) rescue {}
    res.dig("data", "recordId") if res["code"] == 0
  end

  def get_questions(student, record_id)
    response = @conn.get("/stuCurUser/getExamDetailOfficial") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.params = { recordId: record_id }
    end
    res = JSON.parse(response.body) rescue {}
    res.dig("data", "questions") || []
  end

  def save_answer(student, record_id, question_id, choice_val)
    @conn.post("/stuCurUser/saveAnswerOfficial") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.body = {
        recordId: record_id,
        questionId: question_id,
        choice: choice_val
      }
    end
  end
end
