require File.dirname(__FILE__) + '/test_helper.rb'

require "runit/testcase"

#clickclientのテスト。
#約定なしに試せる機能(決済、建玉一覧、約定一覧以外の機能)のテストを実際のサーバーに接続し行う。
#実行時にユーザー名/パスワードを引数で指定すること。
#
# ruby connect_test_fx.rb <CLICK証券のユーザー名>  <CLICK証券のパスワード>
#
class ClickClient_FxTest <  RUNIT::TestCase
  
  # ユーザー名
  USER_NAME = ARGV[0]
  # パスワード
  PASSWORD  = ARGV[1]
  
  #待ち時間。
  #注文変更後、即座に一覧を取得すると変更中の場合があるため、一定時間待つ。
  WAIT = 5
  
  CURRENCY_PAIRS = [
    ClickClient::FX::USDJPY, ClickClient::FX::EURJPY, ClickClient::FX::GBPJPY,
    ClickClient::FX::AUDJPY, ClickClient::FX::NZDJPY, ClickClient::FX::CADJPY,
    ClickClient::FX::CHFJPY, ClickClient::FX::ZARJPY, ClickClient::FX::EURUSD,
    ClickClient::FX::GBPUSD, ClickClient::FX::AUDUSD, ClickClient::FX::EURCHF,
    ClickClient::FX::GBPCHF, ClickClient::FX::USDCHF]  
  
  def setup
    @client = ClickClient::Client.new
  end

  def teardown
  end
  
  # 通貨ペア一覧取得のテスト
  def test_list_currency_pairs
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      # 全一覧取得
      list = fx.list_currency_pairs
      CURRENCY_PAIRS.each {|code|
        info = list[code]
        assert_valid_currency_pair( info, code )
      }
      
      # ClickClient::FX::EURJPY, ClickClient::FX::CADJPY, ClickClient::FX::AUDUSDを取得
      list = fx.list_currency_pairs( [ClickClient::FX::EURJPY, ClickClient::FX::CADJPY, ClickClient::FX::AUDUSD] )
      assert_equals list.size, 3
      assert_valid_currency_pair( list[ClickClient::FX::EURJPY], ClickClient::FX::EURJPY )
      assert_valid_currency_pair( list[ClickClient::FX::CADJPY], ClickClient::FX::CADJPY )
      assert_valid_currency_pair( list[ClickClient::FX::AUDUSD], ClickClient::FX::AUDUSD )
    }
  end
  
  # 現在のレート一覧取得のテスト
  def test_list_rates
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      list = fx.list_rates
      CURRENCY_PAIRS.each {|code|
        info = list[code]
        assert_valid_rate( info, code )
      }
    }
  end
  
  # お知らせ一覧取得のテスト
  def test_list_messages
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      list = fx.list_messages
      list.each {|msg|
        assert_not_nil msg.text
        assert_not_nil msg.title
      }
    }
  end
  
  # 約定一覧取得のテスト
  def test_list_execution_results
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      now = DateTime.now
      
      # 範囲指定のみ
      begin
          list = fx.list_execution_results now - 100, now
      rescue
        puts $! # 約定履歴がないとエラーになるので
      end     
      list.each {|execution_result|
        assert_valid_execution_result( execution_result )
      }
      
      # 範囲指定、種別、通貨ペアコードを指定
      begin 
        list = fx.list_execution_results now - 100, now, ClickClient::FX::TRADE_TYPE_SETTLEMENT, ClickClient::FX::ZARJPY
      rescue
        puts $! # 約定履歴がないとエラーになるので
      end      
      list.each {|execution_result|
        assert_valid_execution_result( execution_result )
      } 
    }
  end
  
  # 余力情報取得のテスト
  def test_get_margin
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      margin = fx.get_margin
      assert_not_nil margin.margin
      assert_not_nil margin.transferable_money_amount 
      assert_not_nil margin.guarantee_money_status 
      assert_not_nil margin.guarantee_money_maintenance_ratio 
      assert_not_nil margin.market_value 
      assert_not_nil margin.appraisal_profit_or_loss_of_open_interest 
      assert_not_nil margin.balance_in_account 
      assert_not_nil margin.balance_of_cach 
      assert_not_nil margin.settlement_profit_or_loss_of_today 
      assert_not_nil margin.settlement_profit_or_loss_of_next_business_day 
      assert_not_nil margin.settlement_profit_or_loss_of_next_next_business_day 
      assert_not_nil margin.swap_profit_or_loss 
      assert_not_nil margin.freezed_guarantee_money 
      assert_not_nil margin.required_guarantee_money 
      assert_not_nil margin.ordered_guarantee_money 
      margin.guarantee_money_list.each{|g|
        assert_not_nil g.currency_pair_code 
        assert_not_nil g.guarantee_money 
      }      
    }
  end  
  
  # 通常注文の発注、変更、キャンセルのテスト
  def test_basic_order
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      list = fx.list_rates
      
      # 注文
      result = fx.order( ClickClient::FX::USDJPY, ClickClient::FX::BUY, 1, {
        :rate=>list[ClickClient::FX::USDJPY].ask_rate - 5, # ask-5円で注文。5円急落しないと約定しないので大丈夫?
        :execution_expression=>ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
        :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_TODAY
      })
      assert_not_nil result.order_no
      order_no = result.order_no
      begin 
      
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::USDJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000 # USDJPNなので1万単位
        assert_equals order.rate, list[ClickClient::FX::USDJPY].ask - 5
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_TODAY
        assert_nil order.expiration_date
        assert_equals order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        #注文変更
        new_rate = list[ClickClient::FX::USDJPY].ask_rate - 5.01
        fx.edit_order( order_no, {
          :rate=>new_rate,
          :execution_expression=>ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
          :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_WEEK_END
        })
        sleep WAIT
        
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::USDJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000 # USDJPNなので1万単位
        assert_equals order.rate.to_s, new_rate.to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_WEEK_END
        assert_nil order.expiration_date
        assert_equals order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
              
      ensure
        # キャンセル
        fx.cancel_order order_no
        
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::USDJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000 # USDJPNなので1万単位
        assert_equals order.rate.to_s, (list[ClickClient::FX::USDJPY].ask_rate - 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_WEEK_END
        assert_nil order.expiration_date
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date         
      end
    }
  end
  
  # OCO注文の発注、変更、キャンセルのテスト
  def test_oco_order
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      list = fx.list_rates
      
      # 注文
      limit_date = DateTime.now + 5
      expect_limit = DateTime.new( limit_date.year, limit_date.mon, limit_date.day, limit_date.hour )
      
      result = fx.order( ClickClient::FX::EURJPY, ClickClient::FX::BUY, 1, {
        :rate=>list[ClickClient::FX::EURJPY].ask_rate - 5, 
        :stop_order_rate=>list[ClickClient::FX::EURJPY].ask_rate + 5, 
        :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
        :expiration_date=>limit_date
      })
      assert_not_nil result.limit_order_no
      limit_order_no = result.limit_order_no
      stop_order_no = result.stop_order_no
      begin 
      
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[limit_order_no]
        assert_equals order.order_no, result.limit_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 5).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        order = orders[stop_order_no]
        assert_equals order.order_no, result.stop_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate + 5).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date        
        
        #注文変更
        limit_date = DateTime.now + 6
        expect_limit = DateTime.new( limit_date.year, limit_date.mon, limit_date.day, limit_date.hour )        
        fx.edit_order( limit_order_no, {
          :stop_order_no=>stop_order_no,
          :rate=>list[ClickClient::FX::EURJPY].ask_rate - 5.01,
          :stop_order_rate=>list[ClickClient::FX::EURJPY].ask_rate + 5.01,
          :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
          :expiration_date=>limit_date
        })
        sleep WAIT
        
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[limit_order_no]
        assert_equals order.order_no, result.limit_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        order = orders[stop_order_no]
        assert_equals order.order_no, result.stop_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate + 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date 
          
      ensure
        # キャンセル
        fx.cancel_order limit_order_no

        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[limit_order_no]
        assert_equals order.order_no, result.limit_order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000 
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date  
        
        order = orders[stop_order_no]
        assert_equals order.order_no, result.stop_order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000 
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate + 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date     
      end
    }
  end
  
  # IFD注文の発注、変更、キャンセルのテスト
  def test_ifd_order
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      list = fx.list_rates
      
      # 注文
      result = fx.order( ClickClient::FX::EURJPY, ClickClient::FX::SELL, 1, {
        :rate=>list[ClickClient::FX::EURJPY].bid_rate + 5, 
        :execution_expression=>ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
        :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_INFINITY,
        :settle=>{
          :unit=>1,
          :sell_or_buy=>ClickClient::FX::BUY,
          :rate=>list[ClickClient::FX::EURJPY].bid_rate + 4,
          :execution_expression=>ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
          :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_INFINITY,          
        }
      })
      assert_not_nil result.order_no
      assert_not_nil result.settlement_order_no
      order_no = result.order_no
      settlement_order_no = result.settlement_order_no
      begin 
      
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].bid_rate + 5).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_INFINITY
        assert_nil order.expiration_date
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        order = orders[settlement_order_no]
        assert_equals order.order_no, result.settlement_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].bid_rate + 4).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_INFINITY
        assert_nil order.expiration_date
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_WAITING # 決済注文は待機中。
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date        
       
        #注文変更
        limit_date = DateTime.now + 6
        expect_limit = DateTime.new( limit_date.year, limit_date.mon, limit_date.day, limit_date.hour )        
        fx.edit_order( order_no, {
          :rate=>list[ClickClient::FX::EURJPY].bid_rate + 5.01,
          :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
          :expiration_date=>limit_date,
          :settle=>{
            :order_no=>settlement_order_no,
            :rate=>list[ClickClient::FX::EURJPY].bid_rate + 4.01,
            :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
            :expiration_date=>limit_date            
          }
        })
        sleep WAIT
        
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].bid_rate + 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        order = orders[settlement_order_no]
        assert_equals order.order_no, result.settlement_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].bid_rate + 4.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_WAITING # 決済注文は待機中。
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date    
      
      ensure
        # キャンセル
        fx.cancel_order order_no

        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].bid_rate + 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date  
        
        order = orders[settlement_order_no]
        assert_equals order.order_no, result.settlement_order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].bid_rate + 4.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
      end
    }
  end
  
  # IFD-OCO
  def test_ifdoco_order
    @client.fx_session(USER_NAME, PASSWORD){|fx|
      list = fx.list_rates
      
      limit_date = DateTime.now + 6
      expect_limit = DateTime.new( limit_date.year, limit_date.mon, limit_date.day, limit_date.hour )
      
      # 注文
      result = fx.order( ClickClient::FX::EURJPY, ClickClient::FX::BUY, 1, {
        :rate=>list[ClickClient::FX::EURJPY].ask_rate - 5, 
        :execution_expression=>ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER,
        :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
        :expiration_date=>limit_date,
        :settle=>{
          :unit=>1,
          :sell_or_buy=>ClickClient::FX::SELL,
          :rate=>list[ClickClient::FX::EURJPY].ask_rate + 4,
          :stop_order_rate=>list[ClickClient::FX::EURJPY].ask_rate - 6, 
          :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
          :expiration_date=>limit_date,        
        }
      })

      assert_not_nil result.order_no
      assert_not_nil result.kessaiSashineChumonBango
      assert_not_nil result.kessaiGyakusashiChumonBango
      order_no = result.order_no
      settlement_order_no = result.kessaiSashineChumonBango
      reverse_settlement_order_no = result.kessaiGyakusashiChumonBango
      begin 
      
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 5).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        order = orders[settlement_order_no]
        assert_equals order.order_no, settlement_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate + 4).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_WAITING # 決済注文は待機中。
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date        
       
        order = orders[reverse_settlement_order_no]
        assert_equals order.order_no, reverse_settlement_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 6 ).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_WAITING # 決済注文は待機中。
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date         
        
        #注文変更      
        limit_date = DateTime.now + 7
        expect_limit = DateTime.new( limit_date.year, limit_date.mon, limit_date.day, limit_date.hour )        
        fx.edit_order( order_no, {
          :rate=>list[ClickClient::FX::EURJPY].ask_rate - 5.01,
          :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
          :expiration_date=>limit_date,
          :settle=>{
            :order_no=>settlement_order_no,
            :stop_order_no=>reverse_settlement_order_no,
            :rate=>list[ClickClient::FX::EURJPY].ask_rate + 4.01,
            :stop_order_rate=>list[ClickClient::FX::EURJPY].ask_rate - 6.01,
            :expiration_type=>ClickClient::FX::EXPIRATION_TYPE_SPECIFIED,
            :expiration_date=>limit_date            
          }
        })
        sleep WAIT
        
        # 注文確認
        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[order_no]
        assert_equals order.order_no, order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_RECEIVED
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
        
        order = orders[settlement_order_no]
        assert_equals order.order_no, settlement_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate + 4.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_WAITING # 決済注文は待機中。
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
       
        order = orders[reverse_settlement_order_no]
        assert_equals order.order_no, reverse_settlement_order_no
        assert_equals order.enable_change_or_cancel, true
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 6.01 ).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert_equals  order.order_state, ClickClient::FX::ORDER_STATE_WAITING # 決済注文は待機中。
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_NOT_FAILED
        assert_nil order.settlement_rate
        assert_nil order.settlement_date
 
      ensure
        # キャンセル
        fx.cancel_order order_no

        orders = fx.list_orders( ClickClient::FX::ORDER_CONDITION_ALL, ClickClient::FX::EURJPY)
        order = orders[order_no]
        assert_equals order.order_no, result.order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_NEW
        assert_equals order.sell_or_buy, ClickClient::FX::BUY
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 5.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date  
        
        order = orders[settlement_order_no]
        assert_equals order.order_no, settlement_order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate + 4.01).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date

        order = orders[reverse_settlement_order_no]
        assert_equals order.order_no, reverse_settlement_order_no
        #assert_equals order.enable_change_or_cancel, true #キャンセル後は変更不可だがタイミングによっては変更可となる。
        assert_equals order.trade_type, ClickClient::FX::TRADE_TYPE_SETTLEMENT
        assert_equals order.sell_or_buy, ClickClient::FX::SELL
        assert_equals order.trade_quantity, 10000
        assert_equals order.rate.to_s, (list[ClickClient::FX::EURJPY].ask_rate - 6.01 ).to_s
        assert_equals order.execution_expression, ClickClient::FX::EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER
        assert_not_nil order.date
        assert_equals order.expiration_type, ClickClient::FX::EXPIRATION_TYPE_SPECIFIED
        assert_equals order.expiration_date, expect_limit
        assert order.order_state == ClickClient::FX::ORDER_STATE_CANCELING || order.order_state == ClickClient::FX::ORDER_STATE_CANCELED # キャンセルorキャンセル中
        assert_not_nil order.failure_reason, ClickClient::FX::FAILURE_REASON_USER # 不成立になる
        assert_nil order.settlement_rate
        assert_nil order.settlement_date        
      end
    }
  end
  
private
  # 通貨ペアコードに値が設定されているか評価する
  def assert_valid_currency_pair( info, code )
    assert_equals code, info.currency_pair_code
    assert_not_nil info.name
    assert_not_nil info.max_trade_quantity.to_i
    assert_not_nil info.min_trade_quantity.to_i
    assert_not_nil info.trade_unit.to_i
  end
  
  # レートに値が設定されているか評価する
  def assert_valid_rate( info, code )
    assert_equals code, info.currency_pair_code
    assert_not_nil info.bid.to_f
    assert_not_nil info.ask.to_f
    assert_not_nil info.day_before_to.to_f
    assert_not_nil info.bid_high.to_f
    assert_not_nil info.bid_low.to_f
    assert_not_nil info.sell_swap.to_i
    assert_not_nil info.buy_swap.to_i
    assert_not_nil info.date
    assert_not_nil info.days_of_grant.to_i
  end
  
  # 約定に値が設定されているか評価する
  def assert_valid_execution_result( execution_result )
    assert_not_nil execution_result.currency_pair_code
  end
end