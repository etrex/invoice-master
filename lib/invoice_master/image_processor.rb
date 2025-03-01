require 'base64'

module InvoiceMaster
  class ImageProcessor
    # 將任何圖片輸入轉換為 base64 格式
    # @param image_input [String, Vips::Image] 圖片輸入，可以是檔案路徑、base64 字串或 Vips::Image 物件
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [String] base64 編碼的圖片
    def self.to_base64(image_input, max_width: nil, max_height: nil, quality: 90)
      # 如果已經是 base64 字串，則直接使用
      if image_input.is_a?(String) && is_base64?(image_input)
        return image_input
      # 如果是檔案路徑，則讀取檔案並轉換為 base64
      elsif image_input.is_a?(String) && File.exist?(image_input)
        return file_to_base64(image_input, max_width: max_width, max_height: max_height, quality: quality)
      # 如果是 Vips::Image 物件，則轉換為 base64
      elsif defined?(Vips::Image) && image_input.is_a?(Vips::Image)
        return vips_to_base64(image_input, max_width: max_width, max_height: max_height, quality: quality)
      else
        raise Error, "Invalid image input: #{image_input}. Must be a valid file path, base64 string, or Vips::Image object."
      end
    end
    
    # 批次處理多張圖片
    # @param image_inputs [Array<String, Vips::Image>] 圖片輸入的陣列
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [Array<String>] base64 編碼的圖片陣列
    def self.batch_to_base64(image_inputs, max_width: nil, max_height: nil, quality: 90)
      image_inputs.map { |input| to_base64(input, max_width: max_width, max_height: max_height, quality: quality) }
    end
    
    # 將檔案轉換為 base64 字串
    # @param file_path [String] 檔案路徑
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [String] base64 編碼的圖片
    def self.file_to_base64(file_path, max_width: nil, max_height: nil, quality: 90)
      # 確認檔案存在
      raise Error, "File not found: #{file_path}" unless File.exist?(file_path)
      
      # 如果需要縮放，則使用 vips 載入並處理
      if (max_width || max_height) && defined?(Vips::Image)
        begin
          # 載入圖片
          image = Vips::Image.new_from_file(file_path)
          # 縮放圖片
          image = resize_image(image, max_width, max_height)
          # 轉換為 base64
          return vips_to_base64(image, quality: quality)
        rescue LoadError
          puts "Warning: ruby-vips gem is not available. Image resizing is disabled."
        rescue => e
          puts "Warning: Failed to resize image: #{e.message}. Using original image."
        end
      end
      
      # 如果不需要縮放或縮放失敗，則直接讀取檔案內容
      file_content = File.binread(file_path)
      
      # 判斷檔案類型
      mime_type = detect_mime_type(file_path)
      
      # 轉換為 base64
      Base64.strict_encode64(file_content)
    end
    
    # 將 Vips::Image 轉換為 base64 字串
    # @param vips_img [Vips::Image] Vips 圖片物件
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [String] base64 編碼的圖片
    def self.vips_to_base64(vips_img, max_width: nil, max_height: nil, quality: 90)
      begin
        # 如果需要縮放，則處理
        if max_width || max_height
          vips_img = resize_image(vips_img, max_width, max_height)
        end
        
        # 將圖片轉換為 JPEG 格式並存入記憶體
        buffer = StringIO.new
        vips_img.jpegsave_buffer(buffer: buffer, Q: quality)
        buffer.rewind
        
        # 轉換為 base64
        Base64.strict_encode64(buffer.read)
      rescue => e
        raise Error, "Failed to convert Vips::Image to base64: #{e.message}"
      end
    end
    
    # 縮放圖片，保持原比例
    # @param image [Vips::Image] 要縮放的圖片
    # @param max_width [Integer, nil] 最大寬度
    # @param max_height [Integer, nil] 最大高度
    # @return [Vips::Image] 縮放後的圖片
    def self.resize_image(image, max_width, max_height)
      return image unless max_width || max_height
      
      # 獲取原始尺寸
      original_width = image.width
      original_height = image.height
      
      # 如果圖片已經小於最大尺寸，則不需要縮放
      if (!max_width || original_width <= max_width) && 
         (!max_height || original_height <= max_height)
        return image
      end
      
      # 計算縮放比例
      scale_x = max_width ? max_width.to_f / original_width : Float::INFINITY
      scale_y = max_height ? max_height.to_f / original_height : Float::INFINITY
      scale = [scale_x, scale_y].min
      
      # 計算新尺寸
      new_width = (original_width * scale).to_i
      new_height = (original_height * scale).to_i
      
      # 縮放圖片
      image.resize(scale)
    end
    
    # 依據檔案副檔名判斷 MIME 類型
    def self.detect_mime_type(file_path)
      extension = File.extname(file_path).downcase
      case extension
      when '.jpg', '.jpeg'
        'image/jpeg'
      when '.png'
        'image/png'
      when '.gif'
        'image/gif'
      when '.webp'
        'image/webp'
      when '.pdf'
        'application/pdf'
      else
        # 預設為 JPEG
        'image/jpeg'
      end
    end
    
    # 檢查字串是否為 base64 編碼
    def self.is_base64?(str)
      # 檢查是否為 data URI
      return true if str.start_with?('data:image/')
      
      # 檢查是否為有效的 base64 字串
      begin
        # 嘗試解碼
        decoded = Base64.strict_decode64(str) rescue nil
        return false unless decoded
        
        # 確保解碼後的內容看起來像圖片（檢查常見圖片格式的標頭）
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
  end
  
  # 確保 Error 類別存在
  Error = Class.new(StandardError) unless defined?(Error)
end
