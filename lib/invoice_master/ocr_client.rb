require 'invoice_master/claude_client'
require 'invoice_master/image_processor'

module InvoiceMaster
  class OcrClient
    def initialize(claude_client: nil, image_processor: nil)
      @claude_client = claude_client || ClaudeClient.new(
        system_prompt: "把這張圖裡所有的文字都寫下來 包含空格和換行",
        image_processor: image_processor
      )
      @image_processor = image_processor || ImageProcessor.new(max_width: 1024, max_height: 1024, quality: 90)
    end

    # 從圖片提取純文字
    # @param image_path [String, Vips::Image] 圖片路徑、base64 字串或 Vips::Image 物件
    # @return [String] 提取的文字
    def call(image_path)
      # 使用 ImageProcessor 將圖片轉換為 base64
      image_data = @image_processor.to_base64(image_path)
      
      # 呼叫 Claude API
      response = @claude_client.call(image_data)
    end
  end
end
