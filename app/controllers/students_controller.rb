class StudentsController < ApplicationController
  # 禁用 CSRF 校验，确保自动化脚本可顺畅 POST
  skip_before_action :verify_authenticity_token

  # 登录系统内置 RSA 公钥
  RSA_PUBLIC_KEY = <<~PEM
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCd2BMEQBlseFB6RK92O3Siqedh
    7XRtvG/w6Pba1bXE2Gs48hLwhho3+x/Pr6tVgjsizQ9vDB/UxFaLjJ41ZIAkza1a
    bxl8W5+Q+/s/ynv73rjdvdHIk3X/imFsz5NV/tWGkl9BRtml6uIzLKBHvYtWpA4x
    IuYevLtf0dBLC4UdbQIDAQAB
    -----END PUBLIC KEY-----
  PEM
  
  def index
    @students = Student.order(created_at: :desc)
	end

  # Params: { username: "...", password: "..." }
  def create
    attrs = student_params
    username = attrs[:username]
    password = attrs[:password]
    base_url = "http://cj.nbjyzx.net:10000"
    
    student = Student.find_or_initialize_by(username: username)
    student.password = password if password.present?

    # 1. 尝试复用 Session
    if student.cookie.present?
      puts "🔄 [#{username}] 尝试复用 Cookie..."
      if student.sync_exams!
        clear_record(student)
        # 必须 return，否则代码会继续往下跑登录流程
        return redirect_to root_path, notice: "添加成功 (Session 复用)"
      end
    end

    # 2. 执行完整登录
    puts "🔑 [#{username}] Session 失效，正在重新登录..."
    result = perform_login_process(base_url, username, password)
    code = result[:code] || result["code"]
    
    if code == 0
      new_cookie = result["cookie"]
      student.update(cookie: new_cookie)
      clear_record(student)
      
      # 这里建议先 sync 后再重定向
      if student.sync_exams!(new_cookie)
        redirect_to root_path, notice: "添加成功 (新登录)"
      else
        redirect_to root_path, alert: "登录成功但同步成绩失败"
      end
    else
      student.update(cookie: nil)
      # 登录失败也必须重定向，否则页面不会刷新清空输入框
      redirect_to root_path, alert: "添加失败: #{result['msg'] || result[:msg]}"
    end
  end

  private

  def clear_record(student)
    student.update(law_record: nil, math_record: nil, chinese_record: nil, social_record: nil)
  end

  # 核心逻辑：获取Session -> 识别计算验证码 -> 加密 -> 提交登录
  def perform_login_process(base_url, username, password, max_retries = 3)
    attempt = 0

    while attempt <= max_retries
      # 1. 初始化并获取带有 JSESSIONID 的 Cookie
      cookie = fetch_session_cookie(base_url)
      return { code: -1, msg: "网络错误：无法获取 Session" } unless cookie

      # 2. 内部调用 AI 识别验证码图片（1+8=? 这种）
      captcha_code = fetch_and_solve_captcha(base_url, cookie)
      
      if captcha_code.blank?
        attempt += 1
        next
      end

      # 3. 加密准备
      aes_key = generate_aes_key
      encrypted_token = rsa_encrypt_aes_key(aes_key)
      encrypted_user  = aes_encrypt(username, aes_key)
      encrypted_pass  = aes_encrypt(password, aes_key)

      # 4. 发送登录请求
      response = execute_login_request(base_url, cookie, encrypted_token, encrypted_user, encrypted_pass, captcha_code)
      
      begin
        # 清洗响应体，防止不可见字符干扰 JSON 解析
        body = response.body.force_encoding('UTF-8').encode('UTF-8', invalid: :replace).gsub(/[\u0000-\u001f\u007f-\u009f]/, '')
        res_json = JSON.parse(body)

        # 逻辑判断
        if res_json['code'] == 0
          return res_json.merge("cookie" => cookie, "status" => "success")
        elsif res_json['msg']&.include?("验证码")
          # 验证码识别错误，自动换图重试
          puts "⚠️ 验证码计算错误 [#{captcha_code}]，正在进行第 #{attempt + 1} 次重试..."
          attempt += 1
        else
          # 其他错误（如用户名或密码错）直接返回，不重试
          return res_json.merge("status" => "fail")
        end
      rescue => e
        return { code: -1, msg: "响应解析失败: #{e.message}" }
      end
    end

    { code: -1, msg: "验证码识别连续 #{max_retries} 次失败，请检查 AI 接口" }
  end

  # --- 内部辅助方法 ---

  # 抓取验证码并调用智谱 API 计算结果
  def fetch_and_solve_captcha(base_url, cookie)
    # 下载图片
    uri = URI("#{base_url}/front/coded")
    req = Net::HTTP::Get.new(uri)
    req['Cookie'] = cookie
    res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    return nil unless res.code == '200'
    
    img_b64 = Base64.strict_encode64(res.body)

    # 智谱 API 调用 (使用你的 600万资源包 Key)
    api_key = "24658ad2d2314bfa81c28a9adf98b097.yy6Lmg7r28YCRCyF"
    ai_uri = URI("https://open.bigmodel.cn/api/paas/v4/chat/completions")
    
    ai_req = Net::HTTP::Post.new(ai_uri, 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{api_key}")
    ai_req.body = {
      model: "glm-4.6v",
      messages: [{ role: "user", content: [
        { type: "text", text: "计算图中数学题结果，只输出数字。" },
        { type: "image_url", image_url: { url: "data:image/jpeg;base64,#{img_b64}" } }
      ]}],
      temperature: 0.1
    }.to_json

    ai_res = Net::HTTP.start(ai_uri.host, ai_uri.port, use_ssl: true) { |http| http.request(ai_req) }
    JSON.parse(ai_res.body).dig("choices", 0, "message", "content")&.scan(/\d+/)&.first
  rescue
    nil
  end

  def fetch_session_cookie(base_url)
    res = Net::HTTP.get_response(URI("#{base_url}/front/coded"))
    res['Set-Cookie'] =~ /JSESSIONID=([^;]+)/ ? "JSESSIONID=#{$1}" : nil
  end

  def execute_login_request(base_url, cookie, token, user, pass, captcha)
    uri = URI("#{base_url}/front/stuuser/toLoginAjax")
    req = Net::HTTP::Post.new(uri.path)
    req['Cookie'] = cookie
    req['token'] = token
    req['X-Requested-With'] = 'XMLHttpRequest'
    req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    req.set_form_data({ 'param1' => user, 'param2' => pass, 'param3' => captcha })
    
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end

  # --- 安全加密逻辑 ---

  def generate_aes_key
    chars = [('0'..'9'), ('A'..'Z'), ('a'..'z')].map(&:to_a).flatten
    (0...16).map { chars.sample }.join
  end

  def rsa_encrypt_aes_key(aes_key)
    rsa = OpenSSL::PKey::RSA.new(RSA_PUBLIC_KEY)
    encrypted = rsa.public_encrypt(aes_key, OpenSSL::PKey::RSA::PKCS1_PADDING)
    Base64.strict_encode64(encrypted)
  end

  def aes_encrypt(data, key)
    cipher = OpenSSL::Cipher.new('AES-128-ECB').encrypt
    cipher.key = key
    Base64.strict_encode64(cipher.update(data) + cipher.final)
  end

  def student_params
    params.require(:student).permit(:username, :password)
  end
end
