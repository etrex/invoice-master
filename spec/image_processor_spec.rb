require 'spec_helper'
require 'invoice_master/image_processor'
require 'base64'
require 'stringio'

RSpec.describe InvoiceMaster::ImageProcessor do
  let(:test_image_path) { '/path/to/test_image.jpg' }
  let(:test_base64) { "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD" }
  let(:encoded_content) { "encoded_image_content" }

  before do
    # 模擬檔案系統操作
    allow(File).to receive(:exist?).with(test_image_path).and_return(true)
    allow(File).to receive(:binread).with(test_image_path).and_return("fake_image_data")
    allow(Base64).to receive(:strict_encode64).and_return(encoded_content)
  end

  describe '.to_base64' do
    context 'with a file path' do
      it 'reads the file and converts it to base64' do
        expect(File).to receive(:exist?).with(test_image_path).and_return(true)
        expect(File).to receive(:binread).with(test_image_path)
        expect(Base64).to receive(:strict_encode64)
        
        result = described_class.to_base64(test_image_path)
        expect(result).to eq(encoded_content)
      end
      
      it 'raises an error if the file does not exist' do
        allow(File).to receive(:exist?).with(test_image_path).and_return(false)
        
        expect { described_class.to_base64(test_image_path) }.to raise_error(InvoiceMaster::Error, /File not found/)
      end
    end
    
    context 'with a base64 string' do
      it 'returns the base64 string unchanged' do
        result = described_class.to_base64(test_base64)
        expect(result).to eq(test_base64)
      end
    end
    
    context 'with an invalid input' do
      it 'raises an error for invalid inputs' do
        expect { described_class.to_base64(nil) }.to raise_error(InvoiceMaster::Error, /Invalid image input/)
      end
    end
  end
  
  describe '.batch_to_base64' do
    it 'processes multiple images and returns an array of base64 strings' do
      paths = ['/path/to/image1.jpg', '/path/to/image2.jpg']
      
      expect(described_class).to receive(:to_base64).with(paths[0]).and_return("base64_1")
      expect(described_class).to receive(:to_base64).with(paths[1]).and_return("base64_2")
      
      result = described_class.batch_to_base64(paths)
      expect(result).to eq(["base64_1", "base64_2"])
    end
  end
  
  describe '.detect_mime_type' do
    it 'detects JPEG mime type' do
      expect(described_class.detect_mime_type('/path/to/image.jpg')).to eq('image/jpeg')
      expect(described_class.detect_mime_type('/path/to/image.jpeg')).to eq('image/jpeg')
    end
    
    it 'detects PNG mime type' do
      expect(described_class.detect_mime_type('/path/to/image.png')).to eq('image/png')
    end
    
    it 'detects GIF mime type' do
      expect(described_class.detect_mime_type('/path/to/image.gif')).to eq('image/gif')
    end
    
    it 'detects WebP mime type' do
      expect(described_class.detect_mime_type('/path/to/image.webp')).to eq('image/webp')
    end
    
    it 'detects PDF mime type' do
      expect(described_class.detect_mime_type('/path/to/document.pdf')).to eq('application/pdf')
    end
    
    it 'defaults to JPEG for unknown extensions' do
      expect(described_class.detect_mime_type('/path/to/unknown.xxx')).to eq('image/jpeg')
    end
  end
  
  describe '.is_base64?' do
    it 'returns true for data URIs' do
      expect(described_class.is_base64?('data:image/jpeg;base64,abc123')).to be true
    end
    
    it 'attempts to decode and check image headers' do
      # Mock the Base64 decode to return a fake JPEG header
      allow(Base64).to receive(:strict_decode64).and_return("\xFF\xD8\xFF" + "a" * 100)
      
      expect(described_class.is_base64?('not_a_data_uri_but_decodable')).to be true
    end
    
    it 'returns false for non-base64 strings' do
      allow(Base64).to receive(:strict_decode64).and_return("not_an_image")
      
      expect(described_class.is_base64?('regular_string')).to be false
    end
    
    it 'returns false when decoding fails' do
      allow(Base64).to receive(:strict_decode64).and_raise(StandardError)
      
      expect(described_class.is_base64?('invalid_base64')).to be false
    end
  end
end
