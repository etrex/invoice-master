require 'invoice_master/claude_client'
require 'json'

module InvoiceMaster
  class LlmClientV3
    SYSTEM_PROMPT = <<~PROMPT
你的任務是從這些圖片區塊中擷取發票的所有資訊，並輸出成指定的 JSON 格式。請注意：

所有數字必須轉換為符合 JSON 規範 (RFC 8259)：
使用純數字，不使用千位分隔符（例如：4000 而不是 4_000 或 4,000）
金額使用小數點，不使用逗號（例如：1234.56）
確保輸出是合法的 JSON 格式
回傳格式必須完全符合以下範例：
所有欄位都必須存在，不可以省略任何欄位
如果某欄位沒有值，必須明確設為 null，不可以省略該欄位
陣列類型的欄位（如 items、tax_details）即使沒有內容也必須保留為空陣列 []，不可以設為 null
特別注意：
店名必須保持原始語言，不要翻譯成英文
商品名稱必須完整保留，不要用通用名稱取代
金額必須完全符合發票上的金額，不要自行計算或修改
發票上有多張收據時，以最詳細的那張為主要收據
    PROMPT

    def initialize
      api_key = ENV.fetch('ANTHROPIC_API_KEY') { raise Error, 'Missing ANTHROPIC_API_KEY environment variable' }
      model = ENV.fetch('ANTHROPIC_MODEL', 'claude-3-7-sonnet-20250219')
      @claude_client = ClaudeClient.new(system_prompt: SYSTEM_PROMPT)
    end

    def extract_invoice_data(image_data)
      # 呼叫 Claude Client 處理圖片資料
      response = @claude_client.call(image_data)
      
      # 解析回應內容
      begin
        # 如果回應是 JSON 字串，則解析它
        if response.is_a?(String)
          # 移除可能的 markdown 標記
          cleaned_content = response.gsub(/```json\n/, '').gsub(/```/, '')
          JSON.parse(cleaned_content)
        else
          # 如果已經是解析過的物件，則直接使用
          response
        end
      rescue JSON::ParserError => e
        raise Error, "Failed to parse LLM response: #{e.message}\nResponse content: #{response}"
      end
    end
  end
  
  # 確保 Error 類別存在
  Error = Class.new(StandardError) unless defined?(Error)
end
