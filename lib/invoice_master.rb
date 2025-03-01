require 'json'
require 'dotenv/load'
require_relative 'invoice_master/parser'
require_relative 'invoice_master/llm_client'
require_relative 'invoice_master/json_schema'
require_relative 'invoice_master/sheet_export'
require_relative 'invoice_master/ocr_client'
require_relative 'invoice_master/claude_client'
require_relative 'invoice_master/image_processor'

module InvoiceMaster
  VERSION = '0.1.0'

  class Error < StandardError; end
  # Your code goes here...
end
