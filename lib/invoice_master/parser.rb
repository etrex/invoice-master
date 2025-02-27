require 'base64'
require 'vips'
require_relative 'llm_client'
require_relative 'json_schema'

module InvoiceMaster
  class Parser
    attr_accessor :debug

    def initialize(llm_client: LlmClient.new, debug: false)
      @llm_client = llm_client
      @debug = debug
    end

    def parse(image_path)
      # 檢查檔案是否存在
      raise Error, "File not found: #{image_path}" unless File.exist?(image_path)

      # 讀取並轉換圖片
      image_content = process_image(image_path)
      debug_log "Image processed and converted to base64"

      # 使用 LLM 解析圖片
      puts "\nSending image to LLM for analysis..."
      json_data = @llm_client.extract_invoice_data(image_content)
      puts "\nLLM Response:"
      puts JSON.pretty_generate(json_data)
      puts "\n"
      debug_log "LLM Response: #{JSON.pretty_generate(json_data)}"

      # 檢查是否為合法的 JSON Hash
      raise Error, "Invalid JSON response" unless json_data.is_a?(Hash)

      # 儲存 JSON 檔案
      output_path = image_path.sub(/\.[^.]+$/, '.json')
      File.write(output_path, JSON.pretty_generate(json_data))
      debug_log "Successfully parsed invoice and saved to #{output_path}"

      json_data
    rescue => e
      puts "Error: #{e.message}"
      raise e
    end

    private

    def process_image(image_path)
      # 讀取圖片
      image = Vips::Image.new_from_file(image_path)
      debug_log "Image format: #{image.get('vips-loader')}"
      debug_log "Original image size: #{image.width}x#{image.height}"

      # 將圖片直接轉換為 base64
      buffer = image.write_to_buffer('.jpg', Q: 90, strip: true)
      debug_log "Image converted to JPEG format (quality: 90, metadata stripped)"
      Base64.strict_encode64(buffer)
    end

    def debug_log(message)
      puts "[DEBUG] #{message}" if @debug
    end
  end
end
