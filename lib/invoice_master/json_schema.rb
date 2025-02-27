require 'json-schema'

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
          "required": ["name"],  
          "properties": {
            "name": {
              "type": "string",
              "description": "店家名稱"
            },
            "tax_id": {
              "type": ["string", "null"],  
              "description": "統一編號"
            },
            "address": {
              "type": ["string", "null"],  
              "description": "店家地址"
            }
          }
        },
        "items": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["name"],  
            "properties": {
              "name": {
                "type": "string",
                "description": "品項名稱"
              },
              "quantity": {
                "type": ["number", "null"],  
                "description": "數量"
              },
              "unit_price": {
                "type": ["number", "null"],  
                "description": "單價"
              },
              "amount": {
                "type": ["number", "null"],  
                "description": "小計"
              }
            }
          }
        }
      }
    }.freeze

    def self.validate(json_data)
      errors = JSON::Validator.fully_validate(INVOICE_SCHEMA, json_data)
      if errors.empty?
        true
      else
        raise Error, "JSON validation failed: #{errors.join(', ')}"
      end
    end
  end
end
