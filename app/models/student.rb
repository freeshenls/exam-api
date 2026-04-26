class Student < ApplicationRecord
  after_update_commit do
    broadcast_replace_later_to(
      self, 
      target: ActionView::RecordIdentifier.dom_id(self), 
      partial: "students/row", 
      locals: { s: self }
    )
  end

  def can_exam?
    # 没有任何进行中的记录，且符合 10 分钟冷却
    records_blank? && updated_at < (10.minutes.ago + 5.seconds)
  end

  def records_blank?
    law_record.blank? && math_record.blank? && chinese_record.blank? && social_record.blank?
  end
  
  # --- 实例方法：这个学生自己去同步 ---
  def sync_exams!(current_cookie = nil)
    # 优先使用传入的新 cookie，如果没有则用数据库存的旧 cookie
    target_cookie = current_cookie || self.cookie
    return false if target_cookie.blank?

    api_data = fetch_exam_list_from_remote(target_cookie)
    
    if api_data && api_data["code"] == 0
      # 此时 self 就是这个学生，直接传数据进去就行
      update_scores_from_json(api_data["data"], target_cookie)
      true
    else
      self.update(cookie: nil)
      false
    end
  end

  # --- 实例方法：把 JSON 里的分数填到自己身上 ---
  def update_scores_from_json(api_data, valid_cookie)
    self.cookie = valid_cookie

    api_data.each do |item|
      score = item["studentScore"]
      
      # 优先获取未完成的 RecordId，如果没有则获取该科目的通用 id
      # 这样在 ExamJob 中可以直接接力继续考试
      record_id = item["unfinishedRecordId"].presence || item["id"]

      case item["papername"]
      when /法律/
        self.law_score = score
        self.law_record = record_id
      when /数学/
        self.math_score = score
        self.math_record = record_id
      when /语文/
        self.chinese_score = score
        self.chinese_record = record_id
      when /社会/
        self.social_score = score
        self.social_record = record_id
      end
    end
    self.save!
  end

  private

  def fetch_exam_list_from_remote(cookie_string)
    uri = URI("http://cj.nbjyzx.net:10000/stuCurUser/getExamListOfficial")
    req = Net::HTTP::Get.new(uri)
    req['Cookie'] = cookie_string
    req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'

    res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    JSON.parse(res.body) rescue nil
  end
end
