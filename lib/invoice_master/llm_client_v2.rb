require 'httparty'
require 'json'

module InvoiceMaster
  class LlmClientV2
    SYSTEM_PROMPT = <<~PROMPT
      用戶會傳遞一組發票，這一組發票是一個交易的所有資訊，你必須把所有的資訊擷取出來，寫成詳細的 json 格式輸出。
      請注意：
      1. 所有數字必須轉換為符合 JSON 規範 (RFC 8259)：
         - 使用純數字，不使用千位分隔符（例如：4000 而不是 4_000 或 4,000）
         - 金額使用小數點，不使用逗號（例如：1234.56）
      2. 確保輸出是合法的 JSON 格式
      3. 回傳格式必須完全符合以下範例：
         - 所有欄位都必須存在，不可以省略任何欄位
         - 如果某欄位沒有值，必須明確設為 null，不可以省略該欄位
         - 陣列類型的欄位（如 items、tax_details）即使沒有內容也必須保留為空陣列 []，不可以設為 null
      4. 特別注意：
         - 店名必須保持原始語言，不要翻譯成英文
         - 商品名稱必須完整保留，不要用通用名稱取代
         - 金額必須完全符合發票上的金額，不要自行計算或修改
         - 發票上有多張收據時，以最詳細的那張為主要收據
      5. 品項處理規則：
         - 必須列出所有品項，每個品項都要分開記錄，不可合併相似品項
         - 即使品項名稱相似，只要是分開列在發票上的，就要分開記錄
         - 每個品項的價格必須完全依照發票上的金額
         - 品項數量必須正確，不要把相似品項的數量加總
      6. 稅金處理規則：
         - 如果發票上標示「内税」，表示價格是內含稅金的金額
         - 對於內含稅的價格：
           * gross_amount 等於發票上的金額（例：2145円）
           * pre_tax_amount 是去除稅金後的金額（例：2145 ÷ 1.1 ≈ 1950円）
           * tax_amount 是稅金金額（例：2145 - 1950 = 195円）
         - 所有金額加總必須完全符合發票上的金額

      == 範例輸出 json ==

      {
        "invoice_id": "TXN20250220-0001",     // 唯一交易識別碼（唯一發票編號）
        "date": "2025-02-20",                 // 交易日期（ISO 8601 格式）
        "time": "14:11:49",                   // 交易時間
        "store": {                            // 商家/店鋪資訊
          "name": "ピッツェリア マルデナポリ",   // 商家名稱（保持原始語言）
          "address": "東京都渋谷区渋谷1-1-1",   // 商家地址
          "building": "渋谷スクランブルスクエア", // 商家所在建物名稱
          "phone": "03-1234-5678",            // 商家聯絡電話
          "registration_number": "T810001031531", // 商家註冊號碼或統一編號
          "other_details": {}                 // 其他補充資訊，無資料時為空物件 {}
        },
        "items": [                            // 品項明細，每筆記錄一個購買品項
          {
            "description": "P, オオバ",        // 商品描述（保持原始語言）
            "quantity": 1,                    // 購買數量
            "pre_tax_unit_price": 1950,       // 單個商品未稅價格（2145 ÷ 1.1）
            "pre_tax_amount": 1950,           // 該品項未稅總金額
            "tax_rate": "10%",                // 該品項適用稅率
            "tax_amount": 195,                // 該品項稅額
            "gross_amount": 2145,             // 該品項含稅總金額（發票上的金額）
            "item_code": null                 // 商品代碼或條碼（若無則為 null）
          },
          {
            "description": "P, フンギ",        // 商品描述（保持原始語言）
            "quantity": 1,                    // 購買數量
            "pre_tax_unit_price": 1950,       // 單個商品未稅價格（2145 ÷ 1.1）
            "pre_tax_amount": 1950,           // 該品項未稅總金額
            "tax_rate": "10%",                // 該品項適用稅率
            "tax_amount": 195,                // 該品項稅額
            "gross_amount": 2145,             // 該品項含稅總金額（發票上的金額）
            "item_code": null                 // 商品代碼或條碼（若無則為 null）
          }
        ],
        "subtotal": {                         // 整筆交易統計
          "pre_tax_total": 3900,              // 全單未稅總金額
          "tax_total": 390                    // 全單稅額總和
        },
        "tax_details": [                      // 按不同稅率統計的稅金分配
          {
            "rate": "10%",                    // 稅率
            "taxable_amount": 3900,           // 該稅率下的未稅金額
            "tax_amount": 390                 // 該稅率下的稅金
          }
        ],
        "total": 4290,                        // 含稅總金額（與發票上的金額完全一致）
        "payment": {                          // 支付資訊
          "method": "credit_card",            // 支付方式
          "amount_paid": 4290,                // 實際支付金額
          "change": 0,                        // 找零金額
          "details": {                        // 支付方式詳細資訊
            "card_type": "MasterCard",        // 信用卡類型
            "card_number_masked": "519480******4609", // 信用卡號遮罩
            "approval_code": "0005381",       // 批准碼
            "transaction_number": "03040-170-20002", // 交易編號
            "expiry_date": null               // 信用卡有效期限（若無則為 null）
          }
        },
        "additional_info": {                  // 附加資訊
          "notes": null,                      // 備註
          "qr_code": null,                    // QR碼資訊
          "other": {                          // 其他補充資訊
            "table_number": "23",             // 桌號
            "server_id": "8936",              // 服務員編號
            "guests": 4                       // 用餐人數
          }
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
        timeout: 300,  # 5 minutes timeout
        read_timeout: 300,  # 5 minutes read timeout
        body: {
          model: @model,
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
