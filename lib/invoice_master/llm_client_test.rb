require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'vips'

module InvoiceMaster
  class LlmClientTest
    def initialize(api_key)
      @api_key = api_key
    end

    def process_image(image_path)
      # 讀取圖片
      image = Vips::Image.new_from_file(image_path)

      # 將圖片直接轉換為 base64
      buffer = image.write_to_buffer('.jpg', Q: 90, strip: true)
      Base64.strict_encode64(buffer)
    end

    def extract_image_content(image_path)
      # 檢查檔案是否存在
      raise Error, "File not found: #{image_path}" unless File.exist?(image_path)

      # 處理圖片
      image_base64 = process_image(image_path)
      
      # Prepare the request body
      body = {
        model: "claude-3-7-sonnet-20250219",
        max_tokens: 20000,
        system: %{CRITICAL: You MUST respond with ONLY a JSON object, no other text. Your entire response must be parseable as JSON.

Your task is to extract information from Japanese receipts into a structured JSON format. Follow these rules carefully:

DATA EXTRACTION RULES:

1. ITEM INFORMATION:
- Record the complete item name exactly as shown
- Record any quantity indicators that appear before the item name
- Record the exact price and tax amount shown
- Do not make assumptions about prices or tax rates

2. DATES AND TIMES:
- Convert dates from YYYY年MM月DD日 to YYYY-MM-DD
- Convert times to 24-hour format (HH:MM)
- Record dates and times exactly as they appear on the receipt

3. STORE INFORMATION:
- Record the complete store name
- Record the full address with all components
- Record all registration numbers and store numbers exactly
- Record phone numbers in the format shown

4. PAYMENT INFORMATION:
- Record the payment method
- Record card details if present
- Record transaction numbers exactly
- Record receipt numbers exactly

EXTRACTION PRINCIPLES:

1. COMPLETENESS:
- Capture all text shown in item descriptions
- Include all parts of addresses and names
- Record all numbers and identifiers fully

2. ACCURACY:
- Do not truncate or abbreviate any text
- Keep all leading zeros in numbers
- Preserve exact formatting of identifiers

3. NO ASSUMPTIONS:
- Do not calculate or validate tax amounts
- Do not standardize item names
- Do not modify any values

JSON Structure:
{
  "invoice_id": string,
  "date": string,
  "time": string,
  "store": {
    "name": string,
    "address": string,
    "building": null,
    "phone": string,
    "registration_number": string,
    "other_details": {
      "store_number": string
    }
  },
  "items": [
    {
      "description": string,
      "quantity": number,
      "pre_tax_unit_price": null,
      "pre_tax_amount": null,
      "tax_rate": string,
      "tax_amount": number,
      "gross_amount": number,
      "item_code": null
    }
  ],
  "tax_details": [
    {
      "rate": string,
      "taxable_amount": null,
      "tax_amount": number
    }
  ],
  "total": number,
  "payment": {
    "method": string,
    "amount_paid": number,
    "change": number,
    "details": {
      "card_type": string,
      "card_number_masked": string,
      "approval_code": null,
      "transaction_number": string,
      "expiry_date": null
    }
  },
  "additional_info": {
    "notes": null,
    "qr_code": null,
    "other": {
      "receipt_number": string
    }
  }
}},
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: image_base64
                }
              }
            ]
          }
        ]
      }

      # Make the API request
      uri = URI.parse("https://api.anthropic.com/v1/messages")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["x-api-key"] = @api_key
      request["anthropic-version"] = "2023-06-01"
      request.body = body.to_json

      puts "Sending image to Claude API..."
      response = http.request(request)
      puts "API Response Status: #{response.code}"

      if response.code == "200"
        result = JSON.parse(response.body)
        puts "Response:"
        puts result.to_json
        puts "\nClaude's Response:"
        puts result["content"][0]["text"]
        return result
      else
        puts "Error: #{response.body}"
        return nil
      end
    end

    # /Users/kami/Library/CloudStorage/Dropbox/旅遊/202502日本/IMG_8390.png
    def expect_response
      JSON.parse(<<~JSON)
      {
        "invoice_id": "A000000000041010",
        "date": "2025-02-12",
        "time": "22:14",
        "store": {
          "name": "LAWSON 名駅椄通北店",
          "address": "愛知県名古屋市中村区名駅3-2",
          "building": null,
          "phone": "052-561-2340",
          "registration_number": "1618000106471",
          "other_details": {
            "store_number": "175478"
          }
        },
        "items": [
          {
            "description": "からあげクン レモン味",
            "quantity": 1,
            "pre_tax_unit_price": null,
            "pre_tax_amount": null,
            "tax_rate": "8%",
            "tax_amount": 248,
            "gross_amount": 248,
            "item_code": null
          },
          {
            "description": "FF カラアゲ ポッケパイ ウエーブ",
            "quantity": 2,
            "pre_tax_unit_price": null,
            "pre_tax_amount": null,
            "tax_rate": "8%",
            "tax_amount": 248,
            "gross_amount": 496,
            "item_code": null
          }
        ],
        "tax_details": [
          {
            "rate": "8%",
            "taxable_amount": null,
            "tax_amount": 55
          }
        ],
        "total": 744,
        "payment": {
          "method": "credit_card",
          "amount_paid": 744,
          "change": 0,
          "details": {
            "card_type": "MASTERCARD",
            "card_number_masked": "****4609",
            "approval_code": null,
            "transaction_number": "10743",
            "expiry_date": null
          }
        },
        "additional_info": {
          "notes": null,
          "qr_code": null,
          "other": {
            "receipt_number": "03753"
          }
        }
      }
      JSON
    end
  end
end
