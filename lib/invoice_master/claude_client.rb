require 'httparty'
require 'json'
require 'base64'
require 'stringio'

module InvoiceMaster
  class ClaudeClient
    def initialize(api_key: nil, 
                   model_name: nil, 
                   system_prompt: '', 
                   max_tokens: 4000, 
                   api_endpoint: 'https://api.anthropic.com/v1/messages')
      @api_key = api_key || ENV.fetch('ANTHROPIC_API_KEY') { raise Error, 'Missing ANTHROPIC_API_KEY environment variable' }
      @model = model_name || ENV.fetch('ANTHROPIC_MODEL', 'claude-3-7-sonnet-20250219')
      @system_prompt = system_prompt
      @max_tokens = max_tokens
      @api_endpoint = api_endpoint
    end

    def call(user_prompt)
      # 處理 user_prompt，支援字串或包含字串和圖片的陣列
      content = process_user_content(user_prompt)
      
      # 建立請求本體
      body = {
        model: @model,
        system: @system_prompt,
        max_tokens: @max_tokens,
        messages: [
          { role: "user", content: content }
        ]
      }

      # 發送請求
      response = HTTParty.post(
        @api_endpoint,
        headers: {
          "Content-Type" => "application/json",
          "x-api-key" => @api_key,
          "anthropic-version" => "2023-06-01"
        },
        body: body.to_json
      )

      handle_response(response)
    end

    private

    def process_user_content(user_prompt)
      # 確保輸入是陣列
      input_array = user_prompt.is_a?(Array) ? user_prompt : [user_prompt]
      
      # 處理每個項目
      input_array.map do |item|
        case item
        when String
          # 檢查是否為 base64 編碼的圖片
          if is_base64_image?(item)
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/jpeg",
                data: item
              }
            }
          else
            # 一般文字
            { type: "text", text: item }
          end
        when ->(obj) { defined?(Vips::Image) && obj.is_a?(Vips::Image) }
          # 處理 Vips::Image 物件，轉換為 base64
          {
            type: "image",
            source: {
              type: "base64",
              media_type: "image/jpeg",
              data: vips_to_base64(item)
            }
          }
        else
          # 不支援的類型
          raise Error, "Unsupported input type: #{item.class}. Only String, base64 encoded images, or Vips::Image are supported."
        end
      end
    end
    
    # 檢查字串是否為有效的 base64 編碼圖片
    def is_base64_image?(str)
      # data URI 格式檢查
      return true if str.start_with?('data:image/')
      
      # 嘗試判斷是否為有效的 base64 字串
      begin
        # 確保字串是有效的 base64 格式
        decoded = Base64.strict_decode64(str) rescue nil
        return false unless decoded
        
        # 確保長度合理且檢查可能的圖片格式標頭
        return decoded.length > 50 && (
          decoded.start_with?("\xFF\xD8\xFF") || # JPEG
          decoded.start_with?("\x89PNG\r\n\x1A\n") || # PNG
          decoded.start_with?("GIF87a") || decoded.start_with?("GIF89a") || # GIF
          (decoded.length > 12 && decoded[8..11] == "WEBP") # WebP
        )
      rescue
        return false
      end
    end
    
    # 將 Vips::Image 轉換為 base64 字串
    def vips_to_base64(vips_img)
      begin
        # 將圖片轉換為 JPEG 格式並存入記憶體
        buffer = StringIO.new
        vips_img.jpegsave_buffer(buffer: buffer)
        buffer.rewind
        
        # 轉換為 base64
        Base64.strict_encode64(buffer.read)
      rescue => e
        raise Error, "Failed to convert Vips::Image to base64: #{e.message}"
      end
    end

    def handle_response(response)
      if response.code != 200
        error_message = response.parsed_response['error'] ? response.parsed_response['error']['message'] : response.body
        raise Error, "API request failed: #{error_message}"
      end

      begin
        parsed_response = JSON.parse(response.body)
        parsed_response['content'][0]['text']
      rescue JSON::ParserError => e
        raise Error, "Failed to parse Claude API response: #{e.message}\nResponse content: #{response.body}"
      rescue StandardError => e
        raise Error, "Unexpected error processing Claude API response: #{e.message}\nResponse content: #{response.body}"
      end
    end
  end

  # 定義通用錯誤類別（如果尚未定義）
  class Error < StandardError; end
end
