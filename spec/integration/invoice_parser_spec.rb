require 'spec_helper'

RSpec.describe 'Invoice Parser Integration' do
  let(:test_image_path) { File.join(File.dirname(__FILE__), '../fixtures/test_invoice.heic') }
  let(:test_json_path) { File.join(File.dirname(__FILE__), '../fixtures/test_invoice.json') }
  let(:test_output_path) { File.join(File.dirname(__FILE__), '../fixtures/output.xlsx') }

  before(:all) do
    # 確保環境變數存在
    raise 'Missing OPENAI_API_KEY' unless ENV['OPENAI_API_KEY']
    
    # 確保已安裝 libheif
    unless system('which heif-convert > /dev/null 2>&1')
      raise 'Missing libheif. Please install it first: brew install libheif'
    end
  end

  after(:each) do
    # 不再刪除 JSON 檔案，讓它保留在 fixtures 目錄
    File.delete(test_output_path) if File.exist?(test_output_path)
  end

  describe 'parsing invoice image' do
    it 'successfully parses HEIC invoice image to JSON' do
      # 檢查測試圖片是否存在
      expect(File).to exist(test_image_path)
      
      # 執行解析指令
      result = system("#{File.join(File.dirname(__FILE__), '../../bin/parse_invoice')} #{test_image_path}")
      expect(result).to be true
      
      # 檢查 JSON 檔案是否產生
      expect(File).to exist(test_json_path)
      
      # 讀取並驗證 JSON 內容
      json_content = JSON.parse(File.read(test_json_path))
      
      # 驗證 JSON 結構
      expect(json_content).to include(
        'invoice_number',
        'date',
        'total_amount'
      )
      
      expect(json_content['seller']).to include(
        'name',
        'tax_id'
      )
      
      expect(json_content['items']).to be_an(Array)
      expect(json_content['items'].first).to include(
        'name',
        'quantity',
        'unit_price',
        'amount'
      )

      puts "Successfully parsed invoice and saved to #{test_json_path}"
    end
  end

  describe 'generating excel sheet' do
    before do
      # 如果 fixtures 目錄中已經有 JSON 檔案，就直接使用它
      unless File.exist?(test_json_path)
        # 先產生一個測試用的 JSON 檔案
        test_data = {
          invoice_number: 'AB123456',
          date: '2024-02-26',
          total_amount: 100,
          seller: {
            name: '測試商店',
            tax_id: '12345678',
            address: '測試地址'
          },
          items: [
            {
              name: '測試商品',
              quantity: 1,
              unit_price: 100,
              amount: 100
            }
          ]
        }
        File.write(test_json_path, JSON.pretty_generate(test_data))
      end
    end

    it 'successfully generates excel file from JSON' do
      # 執行轉換指令
      result = system("#{File.join(File.dirname(__FILE__), '../../bin/generate_sheet')} #{File.dirname(test_json_path)} #{test_output_path}")
      expect(result).to be true
      
      # 檢查 Excel 檔案是否產生
      expect(File).to exist(test_output_path)
      
      # 讀取並驗證 Excel 內容
      workbook = RubyXL::Parser.parse(test_output_path)
      
      # 檢查工作表是否存在
      expect(workbook.worksheets.length).to eq(2)
      expect(workbook.worksheets[0].sheet_name).to eq('發票總表')
      expect(workbook.worksheets[1].sheet_name).to eq('品項明細')
    end
  end
end
