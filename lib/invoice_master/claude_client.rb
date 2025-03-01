require 'httparty'
require 'json'
require 'base64'
require 'stringio'
require_relative 'image_processor'

module InvoiceMaster
  class ClaudeClient
    def initialize(api_key: nil, 
                   model_name: nil, 
                   system_prompt: '', 
                   max_tokens: 4000, 
                   api_endpoint: 'https://api.anthropic.com/v1/messages',
                   image_processor: nil)
      @api_key = api_key || ENV.fetch('ANTHROPIC_API_KEY') { raise Error, 'Missing ANTHROPIC_API_KEY environment variable' }
      @model = model_name || ENV.fetch('ANTHROPIC_MODEL', 'claude-3-7-sonnet-20250219')
      @system_prompt = system_prompt
      @max_tokens = max_tokens
      @api_endpoint = api_endpoint
      @image_processor = image_processor || ImageProcessor.new(max_width: 1024, max_height: 1024, quality: 85)
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
          # 檢查字串是否為檔案路徑
          if File.file?(item)
            # 檔案路徑，使用 ImageProcessor 轉換為 base64
            base64_data = @image_processor.file_to_base64(item)
            format_base64_image(base64_data)
          # 檢查是否為 base64 編碼的圖片
          elsif item.start_with?('data:image/') || (item =~ /^[A-Za-z0-9+\/]+={0,2}$/ && item.length > 100)
            format_base64_image(item)
          else
            # 一般文字
            { type: "text", text: item }
          end
        when ->(obj) { defined?(Vips::Image) && obj.is_a?(Vips::Image) }
          # 處理 Vips::Image 物件，使用 ImageProcessor 轉換為 base64
          base64_data = @image_processor.vips_to_base64(item)
          format_base64_image(base64_data)
        else
          # 不支援的類型
          raise Error, "Unsupported input type: #{item.class}. Only String, file paths, base64 encoded images, or Vips::Image are supported."
        end
      end
    end
    
    # 格式化 base64 圖片為 Claude API 所需格式
    # @param base64_data [String] Base64 編碼的圖片資料
    # @return [Hash] 格式化為 Claude API 所需的圖片物件
    def format_base64_image(base64_data)
      # 移除可能的 data URI 前綴 (例如 "data:image/jpeg;base64,")
      if base64_data.include?('base64,')
        data = base64_data.split('base64,').last
        media_type = base64_data[5..base64_data.index(';')-1]
      else
        data = base64_data
        media_type = "image/jpeg"  # 預設為 JPEG
      end

      {
        type: "image",
        source: {
          type: "base64",
          media_type: media_type,
          data: data
        }
      }
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
