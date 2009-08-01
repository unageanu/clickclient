require File.dirname(__FILE__) + '/../lib/clickclient'

require 'kconv'

#== 利用サンプル
#ローカルサーバーに接続し、結果を表示します。
c = ClickClient::Client.new

# ローカルサーバーへの接続設定
c.host_name = "http://localhost:8000"
c.fx_path = "/webservice/ws-redirect"
c.fx_session( "012345678", "sdfsdf" ) { | fx_session | 
  
  # 通貨ペア一覧取得
  # 引数で取得する通貨ペアコードを配列で指定
  # 指定しない場合すべての通貨ペアの情報を取得。
  puts "\n--- list_currency_pairs"
  list = fx_session.list_currency_pairs [GMO::FX::USDJPY, GMO::FX::EURJPY]
  list.each{ |currency_pair_code, value|  puts value }
  
  # レート一覧取得 
  puts "\n--- list_rates"
  list = fx_session.list_rates
  list.each{ |currency_pair_code, value|  puts value }
  
  # 成り行き注文
  puts "\n--- order - buy"
  puts fx_session.order( GMO::FX::USDJPY, GMO::FX::BUY, 2  )
  puts "\n--- order - sell"
  result = fx_session.order( GMO::FX::USDJPY, GMO::FX::SELL, 1, {
    :slippage=>99,
    :slippage_base_rate=>list[GMO::FX::USDJPY].bid_rate
  })
  puts result
  
  # 成り行き決済注文
  puts "\n--- settle"
  puts fx_session.settle( result.order_no, 1 )
  puts fx_session.settle( result.order_no, 2, {
    :slippage=>99,
    :slippage_base_rate=>list[GMO::FX::USDJPY].bid_rate
  })
  
  # 通常注文
  puts "\n--- order - basic sell"
  result = fx_session.order( GMO::FX::USDJPY, GMO::FX::SELL, 1, {
    :rate=>145.19,
    :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 5, 0 )
  })
  puts result

  # 注文変更
  puts "\n--- edit_order"
  fx_session.edit_order( result.order_no, {
    :rate=>145.19,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_TODAY
  })
  
  # 注文取消し
  puts "\n--- cancel_order"
  fx_session.cancel_order( result.order_no )
  
  # 通常決済注文
  puts "\n--- settle - basic"
  result = fx_session.order( GMO::FX::USDJPY, GMO::FX::SELL, 2, {
    :rate=>145.19,
    :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_TODAY
  })
  puts fx_session.settle( result.order_no, 2, {
    :rate=>146.20,
    :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 5, 0 )
  })
  
  # OCO注文
  puts "\n--- order - oco"
  result = fx_session.order( GMO::FX::USDJPY, GMO::FX::SELL, 1, {
    :rate=>145.19,
    :stop_order_rate=>144.19,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 5, 0 )
  })
  puts result
  
  # OCO注文変更
  puts "\n--- edit - oco"
  fx_session.edit_order( result.limit_order_no, {
    :stop_order_no=>result.stop_order_no,
    :rate=>145.29,
    :stop_order_rate=>144.29,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 6, 0 )
  }) 
  
  # OCO決済注文
  puts "\n--- settle - oco"
  puts fx_session.settle( result.limit_order_no, 2, {
    :rate=>146.20,
    :stop_order_rate=>144.19,
    :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 5, 0 )
  })    
  
  # IFD取引
  puts "\n--- order - ifd"
  result = fx_session.order( GMO::FX::USDJPY, GMO::FX::SELL, 1, {
    :rate=>145.19,
    :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 5, 0 ),
    :settle=>{
      :unit=>1,
      :sell_or_buy=>GMO::FX::BUY,
      :rate=>145.91,
      :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
      :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
      :expiration_date=>DateTime.new( 2007, 11, 5, 0 ),
    }
  })
  puts result   
  
  # IFD注文変更
  puts "\n--- edit - ifd"
  fx_session.edit_order( result.order_no, {
    :rate=>145.29,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_TODAY,
    :settle=>{
      :order_no=>result.settlement_order_no,
      :rate=>145.91,
      :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
      :expiration_date=>DateTime.new( 2007, 11, 6, 0 ),
    }
  })   
  
  # IFD-OCO取引
  puts "\n--- order - ifd-oco"
  result = fx_session.order( GMO::FX::USDJPY, GMO::FX::SELL, 1, {
    :rate=>145.19,
    :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_TODAY,
    :settle=>{
      :unit=>1,
      :sell_or_buy=>GMO::FX::BUY,
      :rate=>145.91,
      :stop_order_rate=>144.15,
      :execution_expression=>GMO::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
      :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
      :expiration_date=>DateTime.new( 2007, 11, 5, 0 ),
    }
  })
  puts result  
  
  # IFD-OCO注文変更
  puts "\n--- edit - ifd-oco"
  fx_session.edit_order( result.order_no, {
    :rate=>145.29,
    :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
    :expiration_date=>DateTime.new( 2007, 11, 6, 0 ),
    :settle=>{
      :order_no=>result.kessaiSashineChumonBango,
      :stop_order_no=>result.kessaiGyakusashiChumonBango,
      :rate=>145.21,
      :stop_order_rate=>144.15,
      :expiration_type=>GMO::FX::EXPIRATION_TYPE_SPECIFIED,
      :expiration_date=>DateTime.new( 2007, 11, 6, 0 ),
    }
  })     
  
  # 注文一覧取得
  # 引数で、注文状態コード(必須)、通貨ペアコード、注文日期間開始日、注文日期間終了日を指定可能。
  puts "\n--- list_orders"
  list = fx_session.list_orders GMO::FX::ORDER_CONDITION_ALL, GMO::FX::EURJPY, Date.new( 2007, 10, 1 ), Date.new( 2007, 11, 1 )
  list.each{ |item|  puts item }  
  
  # 建玉一覧取得
  # 引数で、通貨ペアコードを指定可能。(省略可)
  puts "\n--- list_open_interests"
  list = fx_session.list_open_interests( GMO::FX::EURJPY )
  list.each{ |item|  puts item }
  
  # 約定一覧取得
  # 引数で、取得期間(開始日,終了日)(必須)、通貨ペアコード、取引タイプ(新規Or決済)を指定可能。
  puts "\n--- list_execution_results"
  list = fx_session.list_execution_results( Date.new( 2007, 10, 1 ), Date.new( 2007, 11, 1 ) )
  list.each{ |item|  puts item }   
  list = fx_session.list_execution_results( Date.new( 2007, 10, 1 ), Date.new( 2007, 11, 1 ), GMO::FX::TRADE_TYPE_NEW, GMO::FX::EURJPY )
  list.each{ |item|  puts item }
  
  # 余力情報の取得
  puts "\n--- get_margin"
  puts fx_session.get_margin
  
  # お知らせ一覧取得
  puts "\n--- list_messages"
  list = fx_session.list_messages
  list.each{ |item|  puts item.to_s.tosjis }  
}