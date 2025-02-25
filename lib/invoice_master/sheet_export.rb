require 'rubyXL'
require 'rubyXL/convenience_methods'

module InvoiceMaster
  class SheetExport
    def generate(json_folder, output_file)
      # 讀取所有 JSON 檔案
      json_files = Dir.glob(File.join(json_folder, '*.json'))
      raise Error, 'No JSON files found' if json_files.empty?

      # 建立新的活頁簿
      workbook = RubyXL::Workbook.new

      # 產生發票總表
      generate_summary_sheet(workbook, json_files)
      
      # 產生品項明細表
      generate_items_sheet(workbook, json_files)

      # 儲存檔案
      workbook.write(output_file)
    end

    private

    def generate_summary_sheet(workbook, json_files)
      sheet = workbook[0]
      sheet.sheet_name = '發票總表'

      # 設定標題列
      headers = ['發票號碼', '日期', '店家名稱', '統一編號', '店家地址', '總金額']
      headers.each_with_index do |header, idx|
        sheet.add_cell(0, idx, header)
        sheet[0][idx].change_font_bold(true)
      end

      # 填入發票資料
      json_files.each_with_index do |file, row|
        data = JSON.parse(File.read(file))
        sheet.add_cell(row + 1, 0, data['invoice_number'])
        sheet.add_cell(row + 1, 1, data['date'])
        sheet.add_cell(row + 1, 2, data['seller']['name'])
        sheet.add_cell(row + 1, 3, data['seller']['tax_id'])
        sheet.add_cell(row + 1, 4, data['seller']['address'])
        sheet.add_cell(row + 1, 5, data['total_amount'])
      end

      # 設定欄寬
      sheet.change_column_width(0, 15) # 發票號碼
      sheet.change_column_width(1, 12) # 日期
      sheet.change_column_width(2, 30) # 店家名稱
      sheet.change_column_width(3, 12) # 統一編號
      sheet.change_column_width(4, 40) # 店家地址
      sheet.change_column_width(5, 12) # 總金額
    end

    def generate_items_sheet(workbook, json_files)
      sheet = workbook.add_worksheet('品項明細')

      # 設定標題列
      headers = ['發票號碼', '店家名稱', '品項名稱', '數量', '單價', '小計']
      headers.each_with_index do |header, idx|
        sheet.add_cell(0, idx, header)
        sheet[0][idx].change_font_bold(true)
      end

      # 填入品項資料
      current_row = 1
      json_files.each do |file|
        data = JSON.parse(File.read(file))
        data['items'].each do |item|
          sheet.add_cell(current_row, 0, data['invoice_number'])
          sheet.add_cell(current_row, 1, data['seller']['name'])
          sheet.add_cell(current_row, 2, item['name'])
          sheet.add_cell(current_row, 3, item['quantity'])
          sheet.add_cell(current_row, 4, item['unit_price'])
          sheet.add_cell(current_row, 5, item['amount'])
          current_row += 1
        end
      end

      # 設定欄寬
      sheet.change_column_width(0, 15) # 發票號碼
      sheet.change_column_width(1, 30) # 店家名稱
      sheet.change_column_width(2, 40) # 品項名稱
      sheet.change_column_width(3, 10) # 數量
      sheet.change_column_width(4, 12) # 單價
      sheet.change_column_width(5, 12) # 小計
    end
  end
end
