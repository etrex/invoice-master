require 'vips'
require 'base64'
require 'stringio'
require 'mime/types'

module InvoiceMaster
  class ImageProcessor
    def initialize(max_width: 1024, max_height: 1024, quality: 90)
      @max_width = max_width
      @max_height = max_height
      @quality = quality
    end

    # 將圖片轉換為 base64 字串
    # @param image_input [String, Vips::Image] 圖片路徑、base64 字串或 Vips::Image 物件
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [String] base64 格式的圖片
    def to_base64(image_input, max_width: nil, max_height: nil, quality: nil)
      # 使用傳入參數，若無則使用預設值
      max_width ||= @max_width
      max_height ||= @max_height
      quality ||= @quality

      begin
        # 處理不同類型的輸入
        case image_input
        when String
          if File.exist?(image_input)
            # 讀取檔案
            image = Vips::Image.new_from_file(image_input)
            vips_to_base64(image, max_width: max_width, max_height: max_height, quality: quality)
          elsif is_base64?(image_input)
            # 已經是 base64 字串，直接返回
            return image_input
          else
            raise Error, "Invalid input: #{image_input}. It is not a file path or a base64 string."
          end
        when ->(obj) { defined?(Vips::Image) && obj.is_a?(Vips::Image) }
          # 直接處理 Vips::Image 物件
          vips_to_base64(image_input, max_width: max_width, max_height: max_height, quality: quality)
        else
          raise Error, "Unsupported input type: #{image_input.class}. Only String and Vips::Image are supported."
        end
      rescue => e
        raise Error, "Failed to convert image to base64: #{e.message}"
      end
    end

    # 將多個圖片轉換為 base64 字串陣列
    # @param image_paths [Array<String>] 圖片路徑陣列
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [Array<String>] base64 格式的圖片陣列
    def images_to_base64(image_paths, max_width: nil, max_height: nil, quality: nil)
      # 使用傳入參數，若無則使用預設值
      max_width ||= @max_width
      max_height ||= @max_height
      quality ||= @quality

      image_paths.map { |path| to_base64(path, max_width: max_width, max_height: max_height, quality: quality) }
    end

    # 將 Vips::Image 物件轉換為 base64 字串
    # @param vips_img [Vips::Image] Vips::Image 物件
    # @param max_width [Integer, nil] 最大寬度，如果不為 nil，則會縮放圖片
    # @param max_height [Integer, nil] 最大高度，如果不為 nil，則會縮放圖片
    # @param quality [Integer] JPEG 品質 (1-100)，預設為 90
    # @return [String] base64 格式的圖片
    def vips_to_base64(vips_img, max_width: nil, max_height: nil, quality: nil)
      # 使用傳入參數，若無則使用預設值
      max_width ||= @max_width
      max_height ||= @max_height
      quality ||= @quality

      begin
        # 調整圖片大小（如有需要）
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

      # 計算新尺寸
      new_width = (original_width * scale).to_i
      new_height = (original_height * scale).to_i

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
          (decoded.length > 12 && decoded[8..11] == "WEBP") # WebP
        )
      rescue
        return false
      end
    end

    # 相容性靜態方法，方便使用
    class << self
      def new_with_defaults
        new(max_width: 1024, max_height: 1024, quality: 90)
      end

      def to_base64(image_input, max_width: nil, max_height: nil, quality: 90)
        instance = new(max_width: max_width || 1024, max_height: max_height || 1024, quality: quality)
        instance.to_base64(image_input)
      end

      def images_to_base64(image_paths, max_width: nil, max_height: nil, quality: 90)
        instance = new(max_width: max_width || 1024, max_height: max_height || 1024, quality: quality)
        instance.images_to_base64(image_paths)
      end

      def vips_to_base64(vips_img, max_width: nil, max_height: nil, quality: 90)
        instance = new(max_width: max_width || 1024, max_height: max_height || 1024, quality: quality)
        instance.vips_to_base64(vips_img)
      end

      def is_base64?(str)
        instance = new
        instance.is_base64?(str)
      end
    end
  end

  class Error < StandardError; end
end
