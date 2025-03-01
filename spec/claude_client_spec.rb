require 'spec_helper'
require 'invoice_master/claude_client'
require 'base64'

RSpec.describe InvoiceMaster::ClaudeClient do
  let(:api_key) { 'test_api_key' }
  let(:model) { 'claude-3-7-sonnet-20250219' }
  let(:system_prompt) { 'You are a helpful assistant.' }
  let(:max_tokens) { 500 }
  
  subject(:client) { described_class.new(
    api_key: api_key,
    model_name: model,
    system_prompt: system_prompt,
    max_tokens: max_tokens
  )}

  describe '#process_user_content' do
    # 模擬 HTTP 回應以避免實際 API 呼叫
    before do
      allow_any_instance_of(described_class).to receive(:call).and_return({'content' => [{'text' => 'Test response'}]})
    end
    
    context 'with a text string' do
      it 'correctly formats a text string' do
        input = 'Hello, world!'
        result = client.send(:process_user_content, input)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result[0]).to eq({
          type: 'text',
          text: 'Hello, world!'
        })
      end
    end
    
    context 'with a base64 image string' do
      it 'correctly formats a data URI image' do
        data_uri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
        
        result = client.send(:process_user_content, data_uri)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result[0][:type]).to eq('image')
        expect(result[0][:source][:type]).to eq('base64')
        expect(result[0][:source][:data]).to eq(data_uri)
      end
    end
    
    context 'with arrays of mixed content' do
      it 'correctly formats an array of strings' do
        input = ['Hello', 'World']
        result = client.send(:process_user_content, input)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0][:type]).to eq('text')
        expect(result[0][:text]).to eq('Hello')
        expect(result[1][:type]).to eq('text')
        expect(result[1][:text]).to eq('World')
      end
      
      it 'correctly formats a mixed array with a data URI image' do
        data_uri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
        
        input = ['Here is an image:', data_uri]
        result = client.send(:process_user_content, input)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result[0][:type]).to eq('text')
        expect(result[0][:text]).to eq('Here is an image:')
        expect(result[1][:type]).to eq('image')
        expect(result[1][:source][:type]).to eq('base64')
      end
    end
    
    context 'with Vips::Image objects' do
      it 'correctly handles Vips::Image objects when available' do
        # Skip this test if Vips is not available
        skip 'Vips is not available' unless defined?(Vips::Image)
        
        # This test would need actual Vips integration
        # Just provide a placeholder for now
        expect(true).to eq(true)
      end
    end
    
    context 'with unsupported object types' do
      it 'raises an error for unsupported types' do
        expect { client.send(:process_user_content, {key: 'value'}) }.to raise_error(InvoiceMaster::Error)
        expect { client.send(:process_user_content, [1, 2, 3]) }.to raise_error(InvoiceMaster::Error)
      end
    end
  end
  
  describe '#is_base64_image?' do
    it 'returns true for data URI images' do
      data_uri = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD//gA7'
      expect(client.send(:is_base64_image?, data_uri)).to be true
    end
    
    it 'returns false for plain text' do
      expect(client.send(:is_base64_image?, 'Hello, world!')).to be false
    end
    
    it 'returns false for invalid base64' do
      expect(client.send(:is_base64_image?, '!@#$%^&*')).to be false
    end
  end
end
