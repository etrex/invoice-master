require 'invoice_master/claude_client'
require 'invoice_master/image_processor'

module InvoiceMaster
  class OcrClient
    def initialize
      @claude_client = ClaudeClient.new(system_prompt: "把這張圖裡所有的文字都寫下來 包含空格和換行")
    end

    # 從圖片提取純文字
    # @param image_path [String, Vips::Image] 圖片路徑、base64 字串或 Vips::Image 物件
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [String] 提取的文字
    def call(image_path, max_width: nil, max_height: nil, quality: 90)
      # 使用 ImageProcessor 將圖片轉換為 base64
      image_data = ImageProcessor.to_base64(image_path, max_width: max_width, max_height: max_height, quality: quality)
      
      # 呼叫 Claude API
      response = @claude_client.call(image_data)
    end
  end
end
