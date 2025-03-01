require_relative 'claude_client'
require_relative 'image_processor'

module InvoiceMaster
  class OcrClient
    def initialize(claude_client: nil, image_processor: nil)
      @claude_client = claude_client || ClaudeClient.new(
        system_prompt: "把這張圖裡所有的文字都寫下來 包含空格和換行",
        image_processor: image_processor
      )
    end

    # 從檔案路徑提取純文字
    # @param file_path [String] 圖片檔案路徑
    # @return [String] 提取的文字
    def call(file_path)
      @claude_client.call(file_path)
    end
  end
end
