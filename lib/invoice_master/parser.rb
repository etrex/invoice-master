require 'base64'
require 'vips'

module InvoiceMaster
  class Parser
    def initialize
      @llm_client = LlmClient.new
    end

    def parse(image_path)
      # 讀取並預處理圖片
      image = preprocess_image(image_path)
      
      # 將圖片轉換為 base64
      image_content = encode_image(image)
      
      # 使用 LLM 解析圖片內容
      json_data = @llm_client.extract_invoice_data(image_content)
      
      # 驗證 JSON 格式
      JsonSchema.validate(json_data)
      
      json_data
    rescue Vips::Error => e
      raise Error, "Image processing failed: #{e.message}"
    end

    private

    def preprocess_image(image_path)
      # 載入圖片
      image = Vips::Image.new_from_file(image_path)

      # 圖片預處理：調整大小、增強對比度等
      image = image.resize(0.5) if image.width > 2000 || image.height > 2000
      image = image.colourspace('b-w')  # 轉換為黑白
      image = image.hist_equal          # 直方圖均衡化增強對比度
      
      image
    end

    def encode_image(image)
      # 將圖片轉換為 JPEG 格式的 base64 字串
      temp_file = Tempfile.new(['invoice', '.jpg'])
      begin
        image.jpegsave(temp_file.path, Q: 85)
        Base64.strict_encode64(File.read(temp_file.path))
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end
end
