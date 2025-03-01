require 'spec_helper'
require 'invoice_master/ocr_client'

RSpec.describe InvoiceMaster::OcrClient do
  let(:claude_client_instance) { instance_double(InvoiceMaster::ClaudeClient) }
  let(:test_response) { "這是從圖片中提取的文字\n包含空格和換行" }
  let(:hash_response) { { 'content' => [{'type' => 'text', 'text' => '第一行'}, {'type' => 'text', 'text' => '第二行'}] } }
  let(:test_image_path) { '/path/to/test_image.jpg' }
  let(:test_base64) { "encoded_base64_data" }
  
  subject(:client) { described_class.new }

  before do
    # 模擬 ClaudeClient 的實例
    allow(InvoiceMaster::ClaudeClient).to receive(:new).and_return(claude_client_instance)
    allow(claude_client_instance).to receive(:call).and_return(test_response)
    
    # 模擬 ImageProcessor
    allow(InvoiceMaster::ImageProcessor).to receive(:to_base64).and_return(test_base64)
  end

  describe '#call' do
    it 'uses ImageProcessor to convert the image to base64' do
      expect(InvoiceMaster::ImageProcessor).to receive(:to_base64).with(test_image_path).and_return(test_base64)
      expect(claude_client_instance).to receive(:call).with(test_base64).and_return(test_response)
      
      result = client.call(test_image_path)
      expect(result).to eq(test_response)
    end
    
    context 'with a hash response' do
      it 'extracts and joins the text content' do
        allow(claude_client_instance).to receive(:call).and_return(hash_response)
        
        result = client.call(test_image_path)
        expect(result).to eq("第一行\n第二行")
      end
    end
  end
  
  describe '#call_batch' do
    it 'processes multiple images and returns an array of results' do
      paths = ['/path/to/image1.jpg', '/path/to/image2.jpg']
      
      expect(client).to receive(:call).with(paths[0]).and_return("文字1")
      expect(client).to receive(:call).with(paths[1]).and_return("文字2")
      
      result = client.call_batch(paths)
      expect(result).to eq(["文字1", "文字2"])
    end
  end
end
