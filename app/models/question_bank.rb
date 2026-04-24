class QuestionBank < ApplicationRecord
	validates :exam_question_id, uniqueness: { scope: :paper_id }
end
