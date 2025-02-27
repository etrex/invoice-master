require 'httparty'
require 'json'

module InvoiceMaster
  class LlmClientV2
    SYSTEM_PROMPT = <<~PROMPT
      用戶會傳遞一組發票，這一組發票是一個交易的所有資續，你必須把所有的資訊擷取出來，寫成詳細的 json 格式輸出。
      請注意：
      1. 所有數字必須轉換為符合 JSON 規範 (RFC 8259)：
         - 使用純數字，不使用千位分隔符（例如：4000 而不是 4_000 或 4,000）
         - 金額使用小數點，不使用逗號（例如：1234.56）
      2. 確保輸出是合法的 JSON 格式
      3. 回傳格式必須完全符合以下範例：
         - 所有欄位都必須存在，不可以省略任何欄位
         - 如果某欄位沒有值，必須明確設為 null，不可以省略該欄位
         - 陣列類型的欄位（如 items、tax_details）即使沒有內容也必須保留為空陣列 []，不可以設為 null

      == 範例輸出 json ==

      {
        "invoice_id": "TXN20250220-0001", // 唯一交易識別碼（唯一發票編號）
        "date": "2025-02-20",             // 交易日期（ISO 8601 格式）
        "time": "14:11:49",               // 交易時間
        "store": {                        // 商家/店鋪資訊
          "name": "Example Store",        // 商家名稱
          "address": "東京都渋谷区渋谷1-1-1", // 商家地址
          "building": null,               // 商家所在建物名稱（若無則為 null）
          "phone": "03-1234-5678",        // 商家聯絡電話
          "registration_number": "T810001031531", // 商家註冊號碼或統一編號
          "other_details": {}             // 其他補充資訊，無資料時為空物件 {}
        },
        "items": [                        // 品項明細，每筆記錄一個購買品項
          {
            "description": "商品A",         // 商品描述
            "quantity": 2,                // 購買數量
            "pre_tax_unit_price": 1500,   // 單個商品未稅價格
            "pre_tax_amount": 3000,       // 該品項未稅總金額（quantity * pre_tax_unit_price）
            "tax_rate": "10%",            // 該品項適用稅率
            "tax_amount": 300,            // 該品項稅額
            "gross_amount": 3300,         // 該品項含稅總金額（pre_tax_amount + tax_amount）
            "item_code": null             // 商品代碼或條碼（若無則為 null）
          }
        ],
        "subtotal": {                     // 整筆交易統計
          "pre_tax_total": 5000,          // 全單未稅總金額（所有品項未稅金額之和）
          "tax_total": 460                // 全單稅額總和（所有品項稅額之和）
        },
        "tax_details": [                  // 按不同稅率統計的稅金分配
          {
            "rate": "10%",                // 稅率
            "taxable_amount": 3000,       // 該稅率下的未稅金額
            "tax_amount": 300             // 該稅率下的稅金
          }
        ],
        "total": 5460,                    // 含稅總金額（pre_tax_total + tax_total）
        "payment": {                      // 支付資訊，對帳時非常重要
          "method": "credit_card",        // 支付方式（例如：credit_card、cash、IC卡、電子支付等）
          "amount_paid": 5460,            // 實際支付金額
          "change": 0,                    // 找零金額（如有）
          "details": {                    // 支付方式詳細資訊（如信用卡）
            "card_type": "MasterCard",    // 信用卡類型
            "card_number_masked": "**** **** **** 4609", // 信用卡號遮罩（通常只顯示末四碼）
            "approval_code": "0005381",   // 批准碼
            "transaction_number": "03040-170-20002", // 交易編號
            "expiry_date": "2025-02"      // 信用卡有效期限（若適用）
          }
        },
        "additional_info": {              // 附加資訊，可記錄備註、QR碼、客戶留言等
          "notes": null,                  // 顧客留言或備註（若無則為 null）
          "qr_code": "No.73948888010001", // QR碼資訊（若無則為 null）
          "other": {}                     // 其他補充資訊，無資料時為空物件 {}
        }
      }

      ==
    PROMPT

    def initialize
      @api_key = ENV.fetch('OPENAI_API_KEY') { raise Error, 'Missing OPENAI_API_KEY environment variable' }
      @api_endpoint = ENV.fetch('OPENAI_API_ENDPOINT', 'https://api.openai.com/v1/chat/completions')
      @model = ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini')
    end

    def extract_invoice_data(image_content)
      response = HTTParty.post(
        @api_endpoint,
        headers: {
          'Authorization' => "Bearer #{@api_key}",
          'Content-Type' => 'application/json'
        },
        body: {
          model: @model,
          temperature: 0,
          messages: [
            {
              role: 'system',
              content: SYSTEM_PROMPT
            },
            {
              role: 'user',
              content: [
                {
                  type: 'image_url',
                  image_url: {
                    url: "data:image/jpeg;base64,#{image_content}"
                  }
                }
              ]
            }
          ]
        }.to_json
      )

      raise Error, "API request failed: #{response['error']['message']}" if response['error']

      begin
        content = response['choices'][0]['message']['content']
        # 移除可能的 markdown 標記
        content = content.gsub(/```json\n/, '').gsub(/```/, '')
        JSON.parse(content)
      rescue JSON::ParserError => e
        raise Error, "Failed to parse LLM response: #{e.message}\nResponse content: #{content}"
      end
    end
  end
end
