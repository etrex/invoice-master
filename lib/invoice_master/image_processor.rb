require 'vips'
require 'base64'
require 'stringio'
require 'fileutils'

module InvoiceMaster
  class ImageProcessor
    def initialize(max_width: 1024, max_height: 1024, quality: 90)
      @max_width = max_width
      @max_height = max_height
      @quality = quality
    end

    # 將檔案路徑的圖片轉換為 base64 字串
    # @param file_path [String] 圖片檔案路徑
    # @return [String] base64 格式的圖片
    def file_to_base64(file_path)
      unless File.exist?(file_path)
        raise Error, "File not found: #{file_path}"
      end
      
      # 讀取檔案
      image = Vips::Image.new_from_file(file_path)
      vips_to_base64(image)
    rescue => e
      raise Error, "Failed to convert file to base64: #{e.message}"
    end

    # 將 Vips::Image 物件轉換為 base64 字串
    # @param vips_img [Vips::Image] Vips::Image 物件
    # @return [String] base64 格式的圖片
    def vips_to_base64(vips_img)
      # 調整圖片大小（如有需要）
      vips_img = resize_image(vips_img, @max_width, @max_height)

      # 將圖片轉換為 JPEG 格式並存入記憶體
      jpeg_data = vips_img.jpegsave_buffer(Q: @quality)
      
      # 轉換為 base64
      Base64.strict_encode64(jpeg_data)
    rescue => e
      raise Error, "Failed to convert Vips::Image to base64: #{e.message}"
    end
    
    # 將 base64 編碼的圖片儲存為檔案
    # @param base64_data [String] base64 編碼的圖片資料
    # @param output_path [String] 輸出檔案路徑
    # @return [Boolean] 是否成功儲存
    def base64_to_file(base64_data, output_path)
      # 移除可能的 data URI 前綴 (例如 "data:image/jpeg;base64,")
      if base64_data.include?('base64,')
        base64_data = base64_data.split('base64,').last
      end
      
      # 解碼 base64 資料為二進位資料
      begin
        binary_data = Base64.strict_decode64(base64_data)
      rescue => e
        raise Error, "Failed to decode base64 data: #{e.message}"
      end
      
      # 確保輸出目錄存在
      output_dir = File.dirname(output_path)
      FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)
      
      # 寫入檔案
      begin
        File.binwrite(output_path, binary_data)
        true
      rescue => e
        raise Error, "Failed to write image to #{output_path}: #{e.message}"
      end
    end

    # 調整圖片大小
    # @param vips_img [Vips::Image] Vips::Image 物件
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @return [Vips::Image] 調整大小後的 Vips::Image 物件
    def resize_image(vips_img, max_width, max_height)
      # 如果兩個值都沒有設定，直接返回原圖
      return vips_img if max_width.nil? && max_height.nil?

      # 取得原始尺寸
      original_width = vips_img.width
      original_height = vips_img.height

      # 如果只設定了其中一個值，另一個值根據比例計算
      max_width ||= Float::INFINITY
      max_height ||= Float::INFINITY

      # 計算縮放比例
      scale = [max_width.to_f / original_width, max_height.to_f / original_height].min
      
      # 如果圖片已經小於或等於最大尺寸，直接返回原圖
      return vips_img if scale >= 1

      # 調整圖片大小
      vips_img.resize(scale)
    end

    # 檢查字串是否為 base64 編碼的圖片
    # @param str [String] 要檢查的字串
    # @return [Boolean] 是否為 base64 編碼的圖片
    def is_base64?(str)
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
          (decoded.length > 12 && decoded[8..11] == "WEBP") || # WebP
          decoded.start_with?("\xFF\xD9") # JPEG (from vips)
        )
      rescue
        return false
      end
    end
  end

  class Error < StandardError; end
end
