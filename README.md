# Invoice Master

台灣電子發票自動解析工具 (Taiwan E-invoice Parser and Management Tool)

## 專案簡介

Invoice Master 是一個專門為台灣電子發票設計的自動化解析和管理工具。透過 AI 技術（LLM）自動解析發票圖片內容，並將其轉換為結構化的 JSON 資料，最終可匯出為易於查看的試算表格式。

## 主要功能

- 📸 發票圖片解析：自動讀取發票圖檔
- 🤖 AI 智能辨識：使用 LLM 進行發票內容解析
- 📊 JSON 結構化：將發票資訊轉換為標準化的 JSON 格式
- 📑 批次處理：支援多張發票圖片批次處理
- 📈 試算表輸出：自動將多個 JSON 檔案合併成單一試算表

## 系統需求

- Ruby 3.0+
- Bundler
- 其他依賴套件將列在 Gemfile 中

## 專案結構

```
invoice-master/
├── lib/
│   ├── invoice_master/
│   │   ├── parser.rb        # 發票圖片解析核心
│   │   ├── llm_client.rb    # LLM API 客戶端
│   │   ├── json_schema.rb   # JSON 結構定義
│   │   └── sheet_export.rb  # 試算表匯出功能
│   └── invoice_master.rb
├── bin/
│   ├── parse_invoice        # 圖片轉 JSON 執行檔
│   └── generate_sheet       # JSON 合併試算表執行檔
├── spec/                    # 測試目錄
├── Gemfile
└── README.md
```

## 安裝說明

```bash
# 安裝依賴套件
bundle install
```

## 使用方法

### 1. 解析單張發票

```bash
bin/parse_invoice path/to/invoice.jpg
```

輸出會產生對應的 JSON 檔案。

### 2. 產生試算表

```bash
bin/generate_sheet path/to/json/folder output.xlsx
```

## JSON 格式

即將補充...

## 貢獻指南

歡迎提交 Issue 或 Pull Request 來協助改善這個專案。

## 授權條款

MIT License

## 作者

[etrex](https://github.com/etrex)
