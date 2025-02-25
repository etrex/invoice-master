require 'httparty'
require 'json'

module InvoiceMaster
  class LlmClient
    SYSTEM_PROMPT = <<~PROMPT
      你是一個專業的發票辨識助手。請仔細閱讀發票圖片的文字內容，並將其轉換為結構化的 JSON 資料。
      請注意以下幾點：
      1. 發票號碼通常為8碼
      2. 日期格式需要轉換為 YYYY-MM-DD
      3. 金額必須為數字，不要包含逗號或元字
      4. 品項要正確區分品名、數量、單價和小計
      5. 如果發票上的文字無法辨識，請回傳 null
      
      請依照以下 JSON 格式回傳：
      {
        "invoice_number": "AB123456",
        "date": "2024-02-26",
        "total_amount": 100,
        "seller": {
          "name": "商店名稱",
          "tax_id": "12345678",
          "address": "店家地址"
        },
        "items": [
          {
            "name": "商品名稱",
            "quantity": 1,
            "unit_price": 50,
            "amount": 50
          }
        ]
      }
    PROMPT

    def initialize
      @api_key = ENV.fetch('OPENAI_API_KEY') { raise Error, 'Missing OPENAI_API_KEY environment variable' }
      @api_endpoint = ENV.fetch('OPENAI_API_ENDPOINT', 'https://api.openai.com/v1/chat/completions')
      @model = ENV.fetch('OPENAI_MODEL', 'gpt-4-vision-preview')
    end

    def extract_invoice_data(image_content)
      response = HTTParty.post(
        @api_endpoint,
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: @model,
          messages: [
            {
              role: 'system',
              content: SYSTEM_PROMPT
            },
            {
              role: 'user',
              content: [
                {
                  type: 'image',
                  image_url: {
                    url: "data:image/jpeg;base64,#{image_content}"
                  }
                }
              ]
            }
          ],
          max_tokens: 1000
        }.to_json
      )

      raise Error, "API request failed: #{response['error']['message']}" if response['error']

      begin
        JSON.parse(response['choices'][0]['message']['content'])
      rescue JSON::ParserError => e
        raise Error, "Failed to parse LLM response: #{e.message}"
      end
    end
  end
end
