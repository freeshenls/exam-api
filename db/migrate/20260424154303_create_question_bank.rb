class CreateQuestionBank < ActiveRecord::Migration[7.0]
  def change
    # 统一使用 :question_bank
    create_table :question_bank do |t|
      t.string :paper_id
      t.string :exam_question_id
      t.string :answer
      t.text :question_title

      t.timestamps
    end
    
    # 索引的目标表名必须与上面 create_table 的名字一致
    add_index :question_bank, [:paper_id, :exam_question_id], unique: true, name: 'idx_paper_question'
  end
end
