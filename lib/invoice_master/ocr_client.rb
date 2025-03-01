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

    # 從檔案路徑提取純文字
    # @param file_path [String] 圖片檔案路徑
    # @return [String] 提取的文字
    def call_from_file(file_path)
      # 使用 ImageProcessor 將圖片檔案轉換為 base64
      image_data = @image_processor.file_to_base64(file_path)
      
      # 呼叫 Claude API
      response = @claude_client.call(image_data)
    end
    
    # 從 Vips::Image 提取純文字
    # @param vips_image [Vips::Image] Vips::Image 物件
    # @return [String] 提取的文字
    def call_from_vips(vips_image)
      # 使用 ImageProcessor 將 Vips::Image 轉換為 base64
      image_data = @image_processor.vips_to_base64(vips_image)
      
      # 呼叫 Claude API
      response = @claude_client.call(image_data)
    end
    
    # 從 base64 提取純文字
    # @param base64_data [String] base64 編碼的圖片
    # @return [String] 提取的文字
    def call_from_base64(base64_data)
      # 直接使用 base64 字串
      response = @claude_client.call(base64_data)
    end
    
    # 從檔案路徑提取純文字 (相容舊版 API)
    # @param file_path [String] 圖片檔案路徑
    # @return [String] 提取的文字
    def call(file_path)
      call_from_file(file_path)
    end
  end
end
