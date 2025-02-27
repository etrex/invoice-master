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

      # 讀取並轉換圖片成多個 chunks
      image_chunks = process_image(image_path)
      debug_log "Image processed into #{image_chunks.length} chunks"

      # 使用 LLM 解析圖片
      puts "\nSending image chunks to LLM for analysis..."
      json_data = @llm_client.extract_invoice_data(image_chunks)
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

      # 自動修正圖片方向
      image = image.autorot
      debug_log "After autorot size: #{image.width}x#{image.height}"

      # 如果圖片太大，先縮小到合適大小
      max_dimension = 1024
      if image.width > max_dimension || image.height > max_dimension
        scale = [max_dimension.to_f / image.width, max_dimension.to_f / image.height].min
        image = image.resize(scale)
        debug_log "Resized image to: #{image.width}x#{image.height}"
      end

      buffer = image.write_to_buffer('.jpg', Q: 90, strip: true)
      return [Base64.strict_encode64(buffer)]
      
      # 切割圖片成 512x512 的區塊
      chunk_size = 512
      chunks = []
      
      (0...(image.height)).step(chunk_size) do |y|
        (0...(image.width)).step(chunk_size) do |x|
          # 計算實際的切割區域（處理邊界情況）
          extract_width = [chunk_size, image.width - x].min
          extract_height = [chunk_size, image.height - y].min
          
          # 切割並轉換成 base64
          chunk = image.crop(x, y, extract_width, extract_height)
          buffer = chunk.write_to_buffer('.jpg', Q: 90, strip: true)
          chunks << Base64.strict_encode64(buffer)
          
          debug_log "Created chunk at position (#{x},#{y}) with size #{extract_width}x#{extract_height}"
        end
      end

      debug_log "Split image into #{chunks.length} chunks"
      chunks
    end

    def debug_log(message)
      puts "[DEBUG] #{message}" if @debug
    end
  end
end
