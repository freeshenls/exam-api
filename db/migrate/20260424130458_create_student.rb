class CreateStudent < ActiveRecord::Migration[8.1]
  def change
    create_table :student do |t| # 明确指定表名为单数
      t.string :username
      t.string :password
      t.text   :cookie 
      
      # 存储分数
      t.float :law_score,     default: 0.0
      t.float :math_score,    default: 0.0
      t.float :chinese_score, default: 0.0
      t.float :social_score,  default: 0.0

      # 存储提交成绩用的 recordId
      t.string :law_record
      t.string :math_record
      t.string :chinese_record
      t.string :social_record

      t.timestamps
    end
    add_index :student, :username, unique: true
  end
end
