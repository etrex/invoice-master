require 'httparty'
require 'json'

module InvoiceMaster
  class LlmClientV2
    SYSTEM_PROMPT = <<~PROMPT
      用戶會傳遞一組圖片給你，這組圖片是一張發票照片被切割成的多個區塊。

原始圖片（通常是 iPhone 拍攝的 4032x3024 像素照片）會被切割成 48 個 512x512 像素的小區塊，切割方式如下：

寬度方向：分成 8 個區塊（4032 像素）
高度方向：分成 6 個區塊（3024 像素）
這些區塊的編號和順序是：

```
 1  2  3  4  5  6  7  8
 9 10 11 12 13 14 15 16
17 18 19 20 21 22 23 24
25 26 27 28 29 30 31 32
33 34 35 36 37 38 39 40
41 42 43 44 45 46 47 48
```

切割規則：

從左上角 (0,0) 開始
每個區塊預設大小是 512x512 像素
最右邊和最下面的區塊可能會小於 512 像素
按照從左到右、從上到下的順序編號
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

      ==
    PROMPT

    def initialize
      @api_key = ENV.fetch('OPENAI_API_KEY') { raise Error, 'Missing OPENAI_API_KEY environment variable' }
      @api_endpoint = ENV.fetch('OPENAI_API_ENDPOINT', 'https://api.openai.com/v1/chat/completions')
      @model = ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini')
    end

    def extract_invoice_data(image_data)
      # 如果是單一字串，轉換成陣列處理
      images = image_data.is_a?(Array) ? image_data : [image_data]
      
      # 準備所有圖片的描述
      image_descriptions = images.map.with_index do |base64_image, index|
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,#{base64_image}"
          }
        }
      end

      messages = [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: image_descriptions }
      ]

      response = HTTParty.post(
        "https://api.openai.com/v1/chat/completions",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{@api_key}"
        },
        body: {
          model: "gpt-4o-mini",
          messages: messages,
          max_tokens: 16384
        }.to_json
      )

      handle_response(response)
    end

    private

    def handle_response(response)
      raise Error, "API request failed: #{response['error']['message']}" if response['error']

      begin
        content = response['choices'][0]['message']['content']
        # 移除可能的 markdown 標記
        content = content.gsub(/```json\n/, '').gsub(/```/, '')
        JSON.parse(content)
      rescue JSON::ParserError => e
        raise Error, "Failed to parse LLM response: #{e.message}\nResponse content: #{content}"
      end
    end
  end
end
