require 'httparty'
require 'json'

module InvoiceMaster
  class LlmClientV2
    SYSTEM_PROMPT = <<~PROMPT
用戶會傳遞一組圖片給你，這組圖片是一張發票照片被切割成的多個區塊。

原始圖片（iPhone 直向拍攝的照片，修正方向後為 3024x4032 像素）會被切割成 48 個 512x512 像素的小區塊，切割方式如下：

寬度方向：分成 6 個區塊（3024 像素）
高度方向：分成 8 個區塊（4032 像素）
這些區塊按照從左到右、從上到下的順序編號，如下所示：
（每個數字代表一個區塊的編號，數字之間以兩個空格分隔）

 1  2  3  4  5  6
 7  8  9 10 11 12
13 14 15 16 17 18
19 20 21 22 23 24
25 26 27 28 29 30
31 32 33 34 35 36
37 38 39 40 41 42
43 44 45 46 47 48

切割規則：
1. 從左上角 (0,0) 開始
2. 每個區塊預設大小是 512x512 像素
3. 最右邊的區塊可能會小於 512 像素（因為 3024 ÷ 512 ≈ 5.9）
4. 最下面的區塊可能會小於 512 像素（因為 4032 ÷ 512 ≈ 7.87）
5. 按照從左到右、從上到下的順序編號

你的任務是從這些圖片區塊中擷取發票的所有資訊，並輸出成指定的 JSON 格式。請注意：

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
    - 只填寫發票上實際存在的資訊，不要計算或推測任何數值
    - 如果某個欄位在發票上找不到對應資訊，必須設為 null
    - 發票上有多張收據時，以最詳細的那張為主要收據，找不到資料時再去看另一張
5. 品項處理規則：
    - 必須列出所有品項，每個品項都要分開記錄，不可合併相似品項
    - 即使品項名稱相似，只要是分開列在發票上的，就要分開記錄
    - 每個品項只填寫發票上實際顯示的金額，不要計算或推測其他金額
    - 品項數量必須完全依照發票上的數字
6. 稅金處理規則：
    - 如果發票上有標示「内税」，僅記錄這項資訊
    - 對於所有金額：
      * 只填寫發票上實際顯示的金額
      * 不要計算未稅金額或稅額
      * 如果發票上沒有明確標示的金額，相關欄位必須設為 null
    - 不要自行計算或推測任何金額

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
      "pre_tax_unit_price": null,       // 單個商品未稅價格
      "pre_tax_amount": null,           // 該品項未稅總金額
      "tax_rate": null,                // 該品項適用稅率
      "tax_amount": null,                // 該品項稅額
      "gross_amount": 2145,             // 該品項含稅總金額（發票上的金額）
      "item_code": null                 // 商品代碼或條碼（若無則為 null）
    },
    {
      "description": "P, フンギ",        // 商品描述（保持原始語言）
      "quantity": 1,                    // 購買數量
      "pre_tax_unit_price": null,       // 單個商品未稅價格（2145 ÷ 1.1）
      "pre_tax_amount": null,           // 該品項未稅總金額
      "tax_rate": null,                // 該品項適用稅率
      "tax_amount": null,                // 該品項稅額
      "gross_amount": 2145,             // 該品項含稅總金額（發票上的金額）
      "item_code": null                 // 商品代碼或條碼（若無則為 null）
    }
  ],
  "tax_details": [                      // 按不同稅率統計的稅金分配
    {
      "rate": "10%",                    // 稅率
      "taxable_amount": null,           // 該稅率下的未稅金額
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

    def extract_invoice_data(image_data)
      # 如果是單一字串，轉換成陣列處理
      images = image_data.is_a?(Array) ? image_data : [image_data]
      
      # 準備所有圖片的描述
      image_descriptions = images.map.with_index do |base64_image, index|
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,#{base64_image}",
            "detail": "high"
          }
        }
      end

      messages = [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: image_descriptions }
      ]

      response = HTTParty.post(
        "https://api.openai.com/v1/chat/completions",
        headers: {
          "Content-Type" => "application/json",
          "Authorization" => "Bearer #{@api_key}"
        },
        body: {
          model: "gpt-4o-mini",
          messages: messages,
          max_tokens: 16384
        }.to_json
      )

      handle_response(response)
    end

    private

    def handle_response(response)
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
