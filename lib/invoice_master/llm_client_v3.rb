require 'httparty'
require 'json'
require 'base64'

module InvoiceMaster
  class LlmClientV3
    SYSTEM_PROMPT = <<~PROMPT
      You are an invoice parser. Your task is to extract information from invoice images and output it in a specific JSON format.

      IMPORTANT: You must ONLY output a valid JSON object. Do not include any explanatory text before or after the JSON.

      The JSON should contain the following fields:
      {
        "invoice_id": string,
        "date": string (YYYY-MM-DD format),
        "time": string (HH:mm:ss format),
        "store": {
          "name": string,
          "address": string,
          "building": string,
          "phone": string,
          "registration_number": string,
          "other_details": object
        },
        "items": [
          {
            "description": string,
            "quantity": number,
            "pre_tax_unit_price": number or null,
            "pre_tax_amount": number or null,
            "tax_rate": string or null,
            "tax_amount": number or null,
            "gross_amount": number or null,
            "item_code": string or null
          }
        ],
        "subtotal": {
          "pre_tax_total": number or null,
          "tax_total": number or null
        },
        "tax_details": [
          {
            "rate": string or null,
            "taxable_amount": number or null,
            "tax_amount": number or null
          }
        ],
        "total": number,
        "payment": {
          "method": string,
          "amount_paid": number,
          "change": number,
          "details": object
        },
        "additional_info": {
          "notes": string or null,
          "qr_code": string or null,
          "other": object
        }
      }

      Rules:
      1. Keep all original text in its original language
      2. For missing or unclear values, use null
      3. For numbers, convert text to actual numbers
      4. For tax rates, include the % symbol
      5. Output ONLY the JSON object, no other text
    PROMPT

    def initialize
      @api_key = ENV.fetch('ANTHROPIC_API_KEY') { raise Error, 'Missing ANTHROPIC_API_KEY environment variable' }
      @api_endpoint = ENV.fetch('ANTHROPIC_API_ENDPOINT')
      @model = ENV.fetch('ANTHROPIC_MODEL')
    end

    def extract_invoice_data(image_content)
      headers = {
        'x-api-key' => @api_key,
        'anthropic-version' => '2023-06-01',
        'content-type' => 'application/json'
      }

      body = {
        model: @model,
        max_tokens: 20000,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: [
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: 'image/jpeg',
                  data: image_content
                }
              }
            ]
          }
        ]
      }

      response = HTTParty.post(
        @api_endpoint,
        headers: headers,
        body: body.to_json
      )

      puts "API Response Status: #{response.code}"

      if response.success?
        begin
          puts "Response:"
          puts response.body
          response_json = JSON.parse(response.body)
          content = response_json.dig('content', 0, 'text')
          raise Error, "No content in response" unless content
          # 移除可能的 markdown 標記
          content = content.gsub(/```json\n/, '').gsub(/```/, '')
          JSON.parse(content)
        rescue JSON::ParserError => e
          puts "Error parsing JSON response: #{e.message}"
          puts "Raw response: #{response.body}"
          raise Error, "Failed to parse API response"
        end
      else
        puts "API request failed with status #{response.code}"
        puts "Response body: #{response.body}"
        raise Error, "API request failed: #{response.code} - #{response.body}"
      end
    end
  end
end
