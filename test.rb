require 'dotenv'
Dotenv.load
require_relative 'lib/invoice_master/llm_client_test'

api_key = ENV['ANTHROPIC_API_KEY']
if api_key.nil?
  puts "Please set ANTHROPIC_API_KEY environment variable"
  exit 1
end

client = InvoiceMaster::LlmClientTest.new(api_key)
image_path = '/Users/kami/Library/CloudStorage/Dropbox/旅遊/202502日本/IMG_8390.png'
result = client.extract_image_content(image_path)

puts "\nExpected Response:"
puts client.expect_response.to_json
