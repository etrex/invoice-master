require 'httparty'
require 'json'

module InvoiceMaster
  class LlmClient
    SYSTEM_PROMPT = <<~PROMPT
      把所有的字寫下來，寫成詳細的 json 格式輸出。
      請注意：
      1. 所有數字必須轉換為符合 JSON 規範 (RFC 8259)：
         - 使用純數字，不使用千位分隔符（例如：4000 而不是 4_000 或 4,000）
         - 金額使用小數點，不使用逗號（例如：1234.56）
      2. 確保輸出是合法的 JSON 格式
    PROMPT

    def initialize
      @api_key = ENV.fetch('OPENAI_API_KEY') { raise Error, 'Missing OPENAI_API_KEY environment variable' }
      @api_endpoint = ENV.fetch('OPENAI_API_ENDPOINT', 'https://api.openai.com/v1/chat/completions')
      @model = ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini')
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
          temperature: 0,
          messages: [
            {
              role: 'system',
              content: SYSTEM_PROMPT
            },
            {
              role: 'user',
              content: [
                {
                  type: 'image_url',
                  image_url: {
                    url: "data:image/jpeg;base64,#{image_content}"
                  }
                }
              ]
            }
          ]
        }.to_json
      )

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
