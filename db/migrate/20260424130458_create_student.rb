class CreateStudent < ActiveRecord::Migration[8.1]
  def change
    create_table :student do |t| # 明确指定表名为单数
      t.string :username
      t.string :password
      t.text   :cookie # 存储 JSESSIONID，用 text 更稳
      
      # 默认值设为 0，方便逻辑判断 (if law_count == 0)
      t.float   :law_score,     default: 0.0
      t.integer :law_count,     default: 0
      t.float   :math_score,    default: 0.0
      t.integer :math_count,    default: 0
      t.float   :chinese_score, default: 0.0
      t.integer :chinese_count, default: 0
      t.float   :social_score,  default: 0.0
      t.integer :social_count,  default: 0

      t.timestamps
    end
    add_index :student, :username, unique: true
  end
end
