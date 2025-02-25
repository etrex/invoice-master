module InvoiceMaster
  module JsonSchema
    INVOICE_SCHEMA = {
      "type": "object",
      "required": [
        "invoice_number",
        "date",
        "total_amount",
        "seller",
        "items"
      ],
      "properties": {
        "invoice_number": {
          "type": "string",
          "description": "發票號碼"
        },
        "date": {
          "type": "string",
          "format": "date",
          "description": "開立日期 (YYYY-MM-DD)"
        },
        "total_amount": {
          "type": "number",
          "description": "總金額"
        },
        "seller": {
          "type": "object",
          "required": ["name", "tax_id"],
          "properties": {
            "name": {
              "type": "string",
              "description": "店家名稱"
            },
            "tax_id": {
              "type": "string",
              "description": "統一編號"
            },
            "address": {
              "type": "string",
              "description": "店家地址"
            }
          }
        },
        "items": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["name", "quantity", "unit_price", "amount"],
            "properties": {
              "name": {
                "type": "string",
                "description": "品項名稱"
              },
              "quantity": {
                "type": "number",
                "description": "數量"
              },
              "unit_price": {
                "type": "number",
                "description": "單價"
              },
              "amount": {
                "type": "number",
                "description": "小計"
              }
            }
          }
        }
      }
    }

    def self.validate(json_data)
      JSON::Validator.validate!(INVOICE_SCHEMA, json_data)
    end
  end
end
