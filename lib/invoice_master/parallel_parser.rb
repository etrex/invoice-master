require 'parallel'
require_relative 'parser'

module InvoiceMaster
  class ParallelParser < Parser
    DEFAULT_WORKERS = 4

    def initialize(debug: false, workers: DEFAULT_WORKERS, client_class: LlmClientV2)
      @workers = workers
      @client_class = client_class
      super(debug: debug)
    end

    def parse_files(image_paths)
      results = { success: [], failure: [] }
      
      Parallel.each(image_paths, in_processes: @workers) do |image_path|
        begin
          # 為每個 process 創建新的 LLM client 實例
          @llm_client = @client_class.new unless @llm_client
          
          # 檢查對應的 JSON 檔案是否已存在
          json_path = image_path.sub(/\.[^.]+$/, '.json')
          if File.exist?(json_path)
            puts "Skipping: #{image_path} (JSON already exists)"
            next
          end

          puts "Processing: #{image_path}"
          json_data = parse(image_path)
          
          results[:success] << {
            path: image_path,
            data: json_data
          }
          
          puts "  Successfully processed: #{image_path}"
        rescue => e
          results[:failure] << {
            path: image_path,
            error: e.message
          }
          puts "  Failed to process: #{image_path}"
          puts "  Error: #{e.message}"
        end
      end

      results
    end
  end
end
