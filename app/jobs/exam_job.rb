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

    # 4. 交卷结算
    finish_and_update_score(student, record_id)
  end

  private

  def start_exam(student)
    response = @conn.post("/stuCurUser/startExam_mock") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.body = { examPaperId: @paper_id }
    end
    res = JSON.parse(response.body) rescue {}
    res.dig("data", "recordId") if res["code"] == 0
  end

  def get_questions(student, record_id)
    response = @conn.get("/stuCurUser/getExamDetail_mock") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.params = { recordId: record_id }
    end
    res = JSON.parse(response.body) rescue {}
    res.dig("data", "questions") || []
  end

  def save_answer(student, record_id, question_id, choice_val)
    @conn.post("/stuCurUser/saveAnswer_mock") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.body = {
        recordId: record_id,
        questionId: question_id,
        choice: choice_val
      }
    end
  end

  def finish_and_update_score(student, record_id)
    response = @conn.post("/stuCurUser/submitExam_mock") do |req|
      req.headers['Cookie'] = student.cookie
      req.headers['X-Requested-With'] = "XMLHttpRequest"
      req.body = { recordId: record_id }
    end
    
    res = JSON.parse(response.body) rescue {}
    if res["code"] == 0
      score = res.dig("data", "studentScore") || 0
      case @paper_id
      when "12" then student.update(chinese_score: score)
      when "13" then student.update(math_score: score)
      when "14" then student.update(law_score: score)
      when "15" then student.update(social_score: score)
      end
      student.touch
    end
  end
end
