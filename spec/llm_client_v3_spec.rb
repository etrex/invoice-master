require 'spec_helper'
require 'invoice_master/llm_client_v3'

RSpec.describe InvoiceMaster::LlmClientV3 do
  let(:api_key) { 'test_api_key' }
  let(:max_tokens) { 500 }
  let(:claude_client_instance) { instance_double(InvoiceMaster::ClaudeClient) }
  
  subject(:client) { described_class.new }

  before do
    # 模擬 ClaudeClient 的實例
    allow(InvoiceMaster::ClaudeClient).to receive(:new).and_return(claude_client_instance)
  end

  describe '#extract_invoice_data' do
    context 'when response is a JSON string' do
      let(:json_response) { '{"store_name": "測試商店", "total": 100}' }
      let(:expected_parsed_response) { {'store_name' => '測試商店', 'total' => 100} }
      
      it 'parses the JSON response correctly' do
        allow(claude_client_instance).to receive(:call).and_return(json_response)
        
        result = client.extract_invoice_data('test_image_data')
        expect(result).to eq(expected_parsed_response)
      end
    end
    
    context 'when response is wrapped in markdown code blocks' do
      let(:markdown_response) { "```json\n{\"store_name\": \"測試商店\", \"total\": 100}\n```" }
      let(:expected_parsed_response) { {'store_name' => '測試商店', 'total' => 100} }
      
      it 'removes markdown and parses correctly' do
        allow(claude_client_instance).to receive(:call).and_return(markdown_response)
        
        result = client.extract_invoice_data('test_image_data')
        expect(result).to eq(expected_parsed_response)
      end
    end
    
    context 'when the response is already a parsed object' do
      let(:parsed_response) { {'store_name' => '測試商店', 'total' => 100} }
      
      it 'returns the object directly' do
        allow(claude_client_instance).to receive(:call).and_return(parsed_response)
        
        result = client.extract_invoice_data('test_image_data')
        expect(result).to eq(parsed_response)
      end
    end
    
    context 'when JSON parsing fails' do
      let(:invalid_json) { '{invalid_json: this is not valid}' }
      
      it 'raises an error' do
        allow(claude_client_instance).to receive(:call).and_return(invalid_json)
        
        expect { client.extract_invoice_data('test_image_data') }.to raise_error(InvoiceMaster::Error, /Failed to parse LLM response/)
      end
    end
  end
end
