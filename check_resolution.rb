require 'vips'

image_path = "/Users/kami/Library/CloudStorage/Dropbox/旅遊/202502日本/IMG_8390.png"
image = Vips::Image.new_from_file(image_path)

puts "Original image resolution:"
puts "Width: #{image.width} pixels"
puts "Height: #{image.height} pixels"

# 檢查圖片方向
orientation = image.get("orientation") rescue nil
puts "\nEXIF Orientation: #{orientation || 'Not found'}"

# 自動處理方向
image = image.autorot

puts "\nAfter autorot resolution:"
puts "Width: #{image.width} pixels"
puts "Height: #{image.height} pixels"
puts "Aspect ratio: #{image.width.to_f / image.height.to_f}"
