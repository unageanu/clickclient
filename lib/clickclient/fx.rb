begin
  require 'rubygems'
rescue LoadError
end
require 'httpclient'
require 'rexml/document'
require 'date'

module ClickClient

  class Client

    # FX取引のデフォルトパス
    DEFAULT_FX_PATH = "/webservice/wsfx-redirect"
    
    #
    #===FX取引を開始します。
    #
    #- このAPIを呼び出すとサーバーへのログインが行われます。
    #- ログイン後、引数で指定されたブロックを実行します。ブロックの引数としてClickClient::FX::FxSessionが渡されるので、それを使って取引を行います。
    #- ブロックの実行後、ログアウトします。
    #
    #*userid*::  ユーザーID
    #*password*:: パスワード
    #<b>&block</b>:: 取引処理。引数でClickClient::FX::FxSessionが渡されます。
    #
    def fx_session( userid, password, &block )
      return unless block_given?
      uri = @host_name + ( @fx_path != nil ? @fx_path : DEFAULT_FX_PATH )
      session( uri, userid, password ) { |client, base_uri|
        block.call( ClickClient::FX::FxSession.new( client, base_uri ) )
      }
    end
    
    #FX取引のパス
    attr :fx_path, true
  end
    
  
  #
  #FX取引のクラス/定数が属するモジュールです。
  #
  module FX

    # 通貨ペア: 米ドル-円
    USDJPY = 1
    # 通貨ペア: ユーロ-円
    EURJPY = 2
    # 通貨ペア: イギリスポンド-円
    GBPJPY = 3
    # 通貨ペア: 豪ドル-円
    AUDJPY = 4
    # 通貨ペア: ニュージーランドドル-円
    NZDJPY = 5
    # 通貨ペア: カナダドル-円
    CADJPY = 6
    # 通貨ペア: スイスフラン-円
    CHFJPY = 7
    # 通貨ペア: 南アランド-円
    ZARJPY = 8
    # 通貨ペア: ユーロ-米ドル
    EURUSD = 9
    # 通貨ペア: イギリスポンド-米ドル
    GBPUSD = 10
    # 通貨ペア: 豪ドル-米ドル
    AUDUSD = 11
    # 通貨ペア: ユーロ-スイスフラン
    EURCHF = 12
    # 通貨ペア: イギリスポンド-スイスフラン
    GBPCHF = 13
    # 通貨ペア: 米ドル-スイスフラン
    USDCHF = 14

    # 売買区分: 買い
    BUY = 0
    # 売買区分: 売り
    SELL = 1


    # トレード種別: 新規
    TRADE_TYPE_NEW = 0
    # トレード種別: 決済
    TRADE_TYPE_SETTLEMENT = 1

    # 注文タイプ: 通常
    ORDER_TYPE_NORMAL = 0
    # 注文タイプ: IFD
    ORDER_TYPE_IFD = 1
    # 注文タイプ: OCO
    ORDER_TYPE_OCO = 2
    # 注文タイプ: IFD-OCO
    ORDER_TYPE_IFD_OCO = 3

    # 注文状況: すべて
    ORDER_CONDITION_ALL = 0
    # 注文状況: 注文中
    ORDER_CONDITION_ON_ORDER = 1
    # 注文状況: 取消済
    ORDER_CONDITION_CANCELED = 2
    # 注文状況: 約定
    ORDER_CONDITION_EXECUTION = 3
    # 注文状況: 不成立
    ORDER_CONDITION_FAILED = 4

    # 注文状態: 待機中
    ORDER_STATE_WAITING = 10
    # 注文状態: 受付済み
    ORDER_STATE_RECEIVED = 20
    # 注文状態: 取り消し中
    ORDER_STATE_CANCELING = 21
    # 注文状態: 約定（新規）
    ORDER_STATE_AGREED_NEW = 30
    # 注文状態: 約定（決済）
    ORDER_STATE_AGREED_SETTLEMENT = 97
    # 注文状態: 失効[期限切]
    ORDER_STATE_EXPIRED = 98
    # 注文状態: 取消済
    ORDER_STATE_CANCELED = 99

    # 執行条件: 成行
    EXECUTION_EXPRESSION_MARKET_ORDER = 0
    # 執行条件: 指値
    EXECUTION_EXPRESSION_LIMIT_ORDER = 1
    # 執行条件: 逆指値
    EXECUTION_EXPRESSION_REVERSE_LIMIT_ORDER = 2

    # 有効期限: 当日限り
    EXPIRATION_TYPE_TODAY = 0
    # 有効期限: 週末まで
    EXPIRATION_TYPE_WEEK_END = 1
    # 有効期限: 無期限
    EXPIRATION_TYPE_INFINITY = 2
    # 有効期限: 日付指定
    EXPIRATION_TYPE_SPECIFIED = 3

    # 不成立理由: 不成立ではない
    FAILURE_REASON_NOT_FAILED = 0
    # 不成立理由: 注文状態が「取消済」で、当社オペレータによる取消の場合。
    FAILURE_REASON_GMT = 1
    # 不成立理由: 期限切れ。注文状態が「失効[期限切]」の場合。
    FAILURE_REASON_EXPIRED = 2
    # 不成立理由: 自動（システム）。注文状態が「取消済」で、OCO約定によるもう一方の取消、又はロスカット発動による取消の場合。
    FAILURE_REASON_AUTO = 4
    # 不成立理由: 会員。注文状態が「取消済」で、お客様による取消の場合。
    FAILURE_REASON_USER = 6

    # 証拠金ステータス: 適用外。時価評価総額が0以下の場合。
    GUARANTEE_MONEY_STATUS_NONAPPLOVED = 0
    # 証拠金ステータス: 適正
    GUARANTEE_MONEY_STATUS_APPROPRIATED = 1
    # 証拠金ステータス: ロスカットアラート
    GUARANTEE_MONEY_STATUS_LOSS_CUT_ALERT = 2

    #
    #=== FX取引のためのセッションクラス
    #
    #Client#fx_sessionのブロックの引数として渡されます。詳細はClient#fx_sessionを参照ください。
    #
    class FxSession

      #
      #=== コンストラクタ
      #
      def initialize( client, base_uri )
        @client = client
        @base_uri = base_uri
      end

      #
      #===通貨ペア一覧を取得します。
      #
      #*currency_pair_codes*::  取得したい通貨ペアのコードの配列。nilの場合、全一覧を取得します。
      #<b>戻り値</b>:: ClickClient::FX::CurrencyPairの配列。
      #
      def list_currency_pairs( currency_pair_codes=nil )
        post = ""
        i =0
        if currency_pair_codes != nil
          currency_pair_codes.each{ |code|
            post << "tka[#{i}].tkt="<< code.to_s << "&"
            i += 1
          }
          post.chop
        end
        result = @client.post( @base_uri + "/ws/fx/tsukaPairList.do", post)
        list = {}
        doc = ClickClient.parse( result.content )
        doc.elements.each("./tsukaPairListResponse/tsukaPairList/tsukaPairListItem") { |item|
          v = CurrencyPair.new( item )
          list[v.currency_pair_code] = v
        }
        return list
      end

      #
      #=== 現在のレートの一覧を取得します。
      #
      #<b>戻り値</b>:: ClickClient::FX::Rateの配列。
      #
      def list_rates(  )
        result = @client.post( @base_uri + "/ws/fx/rateList.do")
        list = {}
        doc = ClickClient.parse( result.content )
        doc.elements.each("./rateListResponse/rateList/rateListItem") { |item|
          v = Rate.new( item )
          list[v.currency_pair_code] = v
        }
        return list
      end

      #
      #=== 注文一覧を取得します。
      #
      #*order_condition_code*:: 注文状況コード(必須)
      #*currency_pair_code*:: 通貨ペアコード
      #*from*:: 注文日期間開始日。Dateで指定。例) Date.new(2007, 1, 1)
      #*to*:: 注文日期間終了日。Dateで指定。例) Date.new(2007, 1, 1)
      #<b>戻り値</b>:: ClickClient::FX::Orderの配列。
      #
      def list_orders(  order_condition_code, currency_pair_code=nil, from=nil, to=nil )
        body = "cms=" << order_condition_code.to_s
        body << "&tkt=" << currency_pair_code.to_s
        body << "&cfd=" << from.strftime( "%Y%m%d" ) if from != nil
        body << "&ctd=" << to.strftime( "%Y%m%d" ) if to != nil
        result = @client.post( @base_uri + "/ws/fx/chumonList.do", body)
        list = {}
        doc = ClickClient.parse( result.content )
        doc.elements.each("./chumonListResponse/chumonList/chumonListItem/chumon") { |item|
          order = Order.new( item )
          list[order.order_no] = order
        }
        return list
      end

      #
      #=== 注文を行います。
      #
      #*currency_pair_code*:: 通貨ペアコード(必須)
      #*sell_or_buy*:: 売買区分。ClickClient::FX::BUY,ClickClient::FX::SELLのいずれかを指定します。(必須)
      #*unit*:: 取引数量(必須)
      #*options*:: 注文のオプション。注文方法に応じて以下の情報を設定できます。
      #            - <b>成り行き注文</b>
      #              - <tt>:slippage</tt> .. スリッページ (オプション)
      #              - <tt>:slippage_base_rate</tt> .. スリッページの基準となる取引レート(スリッページが指定された場合、必須。)
      #            - <b>通常注文</b> ※注文レートが設定されていれば通常取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:execution_expression</tt> .. 執行条件。ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER等を指定します(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>OCO注文</b> ※逆指値レートが設定されていればOCO取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:stop_order_rate</tt> .. 逆指値レート(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>IFD注文</b> ※決済取引の指定があればIFD取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:execution_expression</tt> .. 執行条件。ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER等を指定します(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #              - <tt>:settle</tt> .. 決済取引の指定。マップで指定します。
      #                - <tt>:unit</tt> .. 決済取引の取引数量(必須)
      #                - <tt>:sell_or_buy</tt> .. 決済取引の売買区分。ClickClient::FX::BUY,ClickClient::FX::SELLのいずれかを指定します。(必須)
      #                - <tt>:rate</tt> .. 決済取引の注文レート(必須)
      #                - <tt>:execution_expression</tt> .. 決済取引の執行条件。ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER等を指定します(必須)
      #                - <tt>:expiration_type</tt> .. 決済取引の有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #                - <tt>:expiration_date</tt> .. 決済取引の有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>IFD-OCO注文</b> ※決済取引の指定と逆指値レートの指定があればIFD-OCO取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:execution_expression</tt> .. 執行条件。ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER等を指定します(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #              - <tt>:settle</tt> .. 決済取引の指定。マップで指定します。
      #                - <tt>:unit</tt> .. 決済取引の取引数量(必須)
      #                - <tt>:sell_or_buy</tt> .. 決済取引の売買区分。ClickClient::FX::BUY,ClickClient::FX::SELLのいずれかを指定します。(必須)
      #                - <tt>:rate</tt> .. 決済取引の注文レート(必須)
      #                - <tt>:stop_order_rate</tt> .. 決済取引の逆指値レート(必須)
      #                - <tt>:expiration_type</tt> .. 決済取引の有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #                - <tt>:expiration_date</tt> .. 決済取引の有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #<b>戻り値</b>:: ClickClient::FX::OrderResult
      #
      def order ( currency_pair_code, sell_or_buy, unit, options={} )
        path = nil
        body = "tkt=#{currency_pair_code.to_s}"
        if ( options[:settle] != nil  )
          if ( options[:settle][:stop_order_rate] != nil)
             # 逆指値レートと決済取引の指定があればIFD-OCO取引
             raise "options[:settle][:rate] is required." if options[:settle][:rate] == nil
             path = "/ws/fx/ifdOcoChumon.do"
             body << "&kc.grp=#{options[:settle][:stop_order_rate].to_s}"
             body << "&kc.srp=#{options[:settle][:rate].to_s}"
          else
             # 決済取引の指定のみがあればIFD取引
             raise "options[:settle][:rate] is required." if options[:settle][:rate] == nil
             raise "options[:settle][:execution_expression] is required." if options[:settle][:execution_expression] == nil
             path = "/ws/fx/ifdChumon.do"
             body << "&kc.crp=#{options[:settle][:rate].to_s}"
             body << "&kc.sjt=#{options[:settle][:execution_expression].to_s}"
          end
          raise "options[:rate] is required." if options[:rate] == nil
          raise "options[:execution_expression] is required." if options[:execution_expression] == nil
          raise "options[:expiration_type] is required." if options[:expiration_type] == nil
          body << "&sc.bbt=#{sell_or_buy.to_s}"
          body << "&sc.crp=#{options[:rate].to_s}"
          body << "&sc.sjt=#{options[:execution_expression].to_s}"
          body << "&sc.thn=#{unit.to_s}"
          body << "&sc.dat=#{options[:expiration_type].to_s}"
          body << "&sc.ykd=" << options[:expiration_date].strftime( "%Y%m%d%H" ) if options[:expiration_date] != nil

          raise "options[:settle][:rate] is required." if options[:settle][:rate] == nil
          raise "options[:settle][:sell_or_buy] is required." if options[:settle][:sell_or_buy] == nil
          raise "options[:settle][:unit] is required." if options[:settle][:unit] == nil
          raise "options[:settle][:expiration_type] is required." if options[:expiration_type] == nil
          body << "&kc.bbt=#{options[:settle][:sell_or_buy].to_s}"
          body << "&kc.dat=#{options[:settle][:expiration_type].to_s}"
          body << "&kc.thn=#{options[:settle][:unit].to_s}"
          body << "&kc.ykd=" << options[:settle][:expiration_date].strftime( "%Y%m%d%H" ) if options[:settle][:expiration_date] != nil
        elsif ( options[:rate] != nil )
          if ( options[:stop_order_rate] != nil )
            # 逆指値レートが指定されていればOCO取引
            path = "/ws/fx/ocoChumon.do"
            body << "&srp=#{options[:rate].to_s}"
            body << "&grp=#{options[:stop_order_rate].to_s}"
          else
            # そうでなければ通常取引
            raise "options[:execution_expression] is required." if options[:execution_expression] == nil
            path = "/ws/fx/tsujoChumon.do"
            body << "&crp=#{options[:rate].to_s}"
            body << "&sjt=#{options[:execution_expression].to_s}"
          end
          raise "options[:expiration_type] is required." if options[:expiration_type] == nil
          body << "&bbt=#{sell_or_buy.to_s}"
          body << "&thn=#{unit.to_s}"
          body << "&dat=#{options[:expiration_type].to_s}"
          body << "&ykd=" << options[:expiration_date].strftime( "%Y%m%d%H" ) if options[:expiration_date] != nil
        else
          # 成り行き
          path = "/ws/fx/nariyukiChumon.do"
          body << "&bbt=#{sell_or_buy.to_s}&thn=#{unit.to_s}"
          if ( options[:slippage] != nil )
            raise "if you use a slippage,  options[:slippage_base_rate] is required." if options[:slippage_base_rate] == nil
            body << "&slp=#{options[:slippage].to_s}&gnp=#{options[:slippage_base_rate].to_s}"
          end
        end
        result = @client.post( @base_uri + path, body)
        doc = ClickClient.parse( result.content )
        return OrderResult.new( doc.root )
      end
      
      #
      #=== 注文を変更します。
      #
      #変更可能な注文とその値は次のとおりです。成り行き注文は変更できません。
      #- <b>通常注文</b>
      #  - 注文レート
      #  - 有効期限
      #  - 有効日時
      #- <b>IFD注文</b>
      #  - 新規注文レート
      #  - 新規有効期限
      #  - 新規有効日時
      #  - 決済注文レート
      #  - 決済有効期限
      #  - 決済有効日時
      #- <b>OCO注文</b>
      #  - 注文レート
      #  - 逆指値レート
      #  - 有効期限
      #  - 有効日時
      #- <b>IFD-OCO注文</b>
      #  - 新規注文レート
      #  - 新規有効期限
      #  - 新規有効日時
      #  - 決済注文レート
      #  - 決済注文逆指値レート
      #  - 決済有効期限
      #  - 決済有効日時
      #
      #*order_no*:: 注文番号
      #*options*:: 注文のオプション。注文方法に応じて以下の情報を設定できます。
      #            - <b>通常注文</b> ※注文レートが設定されていれば通常取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>OCO注文</b> ※逆指値番号が設定されていればOCO取引となります。
      #              - <tt>:stop_order_no</tt> .. 逆指値注文番号(必須)
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:stop_order_rate</tt> .. 逆指値レート(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>IFD注文</b> ※決済取引の指定のみがあればIFD取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #              - <tt>:settle</tt> .. 決済取引の指定。マップで指定します。
      #                - <tt>:order_no</tt> .. 決済注文番号(必須)
      #                - <tt>:rate</tt> .. 決済取引の注文レート(必須)
      #                - <tt>:expiration_type</tt> .. 決済取引の有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #                - <tt>:expiration_date</tt> .. 決済取引の有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>IFD-OCO注文</b> ※決済逆指値注文番号と決済取引の指定があればIFD-OCO取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #              - <tt>:settle</tt> .. 決済取引の指定。マップで指定します。
      #                - <tt>:order_no</tt> .. 決済注文番号(必須)
      #                - <tt>:stop_order_no</tt> .. 逆指値決済注文番号(必須)
      #                - <tt>:rate</tt> .. 決済取引の注文レート(必須)
      #                - <tt>:stop_order_rate</tt> .. 決済取引の逆指値レート(必須)
      #                - <tt>:expiration_type</tt> .. 決済取引の有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #                - <tt>:expiration_date</tt> .. 決済取引の有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #<b>戻り値</b>:: なし
      #
      def edit_order ( order_no, options )
        
        body = ""
        path = nil
        if ( options[:settle] != nil  )
          if ( options[:settle][:stop_order_no] != nil)
            # 決済逆指値注文番号と決済取引の指定があればIFD-OCO取引
            raise "options[:settle][:order_no] is required." if options[:settle][:order_no] == nil
            raise "options[:settle][:rate] is required." if options[:settle][:rate] == nil
            raise "options[:settle][:stop_order_rate] is required." if options[:settle][:stop_order_rate] == nil
            path = "/ws/fx/ifdOcoChumonHenko.do"
            body << "kc.sck=#{options[:settle][:order_no].to_s}"
            body << "&kc.gck=#{options[:settle][:stop_order_no].to_s}"
            body << "&kc.srp=#{options[:settle][:rate].to_s}"
            body << "&kc.grp=#{options[:settle][:stop_order_rate].to_s}"             
          else
            # 決済取引の指定のみがあればIFD取引
            raise "options[:settle][:order_no] is required." if options[:settle][:order_no] == nil
            raise "options[:settle][:rate] is required." if options[:settle][:rate] == nil
            path = "/ws/fx/ifdChumonHenko.do"
            body << "kc.cmk=#{options[:settle][:order_no].to_s}"
            body << "&kc.crp=#{options[:settle][:rate].to_s}"
          end
          raise "options[:rate] is required." if options[:rate] == nil
          raise "options[:expiration_type] is required." if options[:expiration_type] == nil
          body << "&sc.cmk=#{order_no.to_s}"
          body << "&sc.crp=#{options[:rate].to_s}"
          body << "&sc.dat=#{options[:expiration_type].to_s}"
          body << "&sc.ykd=" << options[:expiration_date].strftime( "%Y%m%d%H" ) if options[:expiration_date] != nil

          raise "options[:settle][:rate] is required." if options[:settle][:rate] == nil
          raise "options[:settle][:expiration_type] is required." if options[:expiration_type] == nil
          body << "&kc.dat=#{options[:settle][:expiration_type].to_s}"
          body << "&kc.ykd=" << options[:settle][:expiration_date].strftime( "%Y%m%d%H" ) if options[:settle][:expiration_date] != nil
        elsif ( options[:rate] != nil )
          if ( options[:stop_order_no] != nil )
            # 逆指値番号が指定されていればOCO取引
            path = "/ws/fx/ocoChumonHenko.do"
            body << "sck=#{order_no.to_s}"
            body << "&gck=#{options[:stop_order_no].to_s}"
            body << "&srp=#{options[:rate].to_s}"
            body << "&grp=#{options[:stop_order_rate].to_s}"
          else
            # そうでなければ通常取引
            raise "options[:rate] is required." if options[:rate] == nil
            path = "/ws/fx/tsujoChumonHenko.do"
            body << "cmk=#{order_no.to_s}"
            body << "&crp=#{options[:rate].to_s}"
          end
          raise "options[:expiration_type] is required." if options[:expiration_type] == nil
          body << "&dat=#{options[:expiration_type].to_s}"
          body << "&ykd=" << options[:expiration_date].strftime( "%Y%m%d%H" ) if options[:expiration_date] != nil
        end        
        
        result = @client.post( @base_uri + path, body)
        ClickClient.parse( result.content )
      end

      #
      #=== 注文をキャンセルします。
      #
      #*order_no*:: 注文番号
      #<b>戻り値</b>:: なし
      #
      def cancel_order ( order_no )
        result = @client.post( @base_uri + "/ws/fx/chumonTorikeshi.do", "cmk=#{order_no.to_s}")
        ClickClient.parse( result.content )
      end

      #
      #=== 決済注文を行います。
      #
      #*open_interest_no*:: 決済する建玉番号
      #*unit*:: 取引数量
      #*options*:: 決済注文のオプション。注文方法に応じて以下の情報を設定できます。
      #            - <b>成り行き注文</b>
      #              - <tt>:slippage</tt> .. スリッページ (オプション)
      #              - <tt>:slippage_base_rate</tt> .. スリッページの基準となる取引レート(スリッページが指定された場合、必須。)
      #            - <b>通常注文</b> ※注文レートが設定されていれば通常取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:execution_expression</tt> .. 執行条件。ClickClient::FX::EXECUTION_EXPRESSION_LIMIT_ORDER等を指定します(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #            - <b>OCO注文</b> ※注文レートと逆指値レートが設定されていればOCO取引となります。
      #              - <tt>:rate</tt> .. 注文レート(必須)
      #              - <tt>:stop_order_rate</tt> .. 逆指値レート(必須)
      #              - <tt>:expiration_type</tt> .. 有効期限。ClickClient::FX::EXPIRATION_TYPE_TODAY等を指定します(必須)
      #              - <tt>:expiration_date</tt> .. 有効期限が「日付指定(ClickClient::FX::EXPIRATION_TYPE_SPECIFIED)」の場合の有効期限をDateで指定します。(有効期限が「日付指定」の場合、必須)
      #<b>戻り値</b>:: ClickClient::FX::SettleResult
      #
      def settle ( open_interest_no, unit, options={} )
        path = nil
        body = "tga[0].tgk=#{open_interest_no.to_s}&tga[0].thn=#{unit.to_s}"
        if ( options[:rate] != nil && options[:stop_order_rate] != nil )
          # レートと逆指値レートが指定されていればOCO取引
          path = "/ws/fx/ocoKessaiChumon.do"
          raise "options[:expiration_type] is required." if options[:expiration_type] == nil
          body << "&srp=#{options[:rate].to_s}"
          body << "&grp=#{options[:stop_order_rate].to_s}"
          body << "&dat=#{options[:expiration_type].to_s}"
          body << "&ykd=" << options[:expiration_date].strftime( "%Y%m%d%H" ) if options[:expiration_date] != nil
        elsif ( options[:rate] != nil )
          # レートが指定されていれば通常取引
          path = "/ws/fx/tsujoKessaiChumon.do"
          raise "options[:execution_expression] is required." if options[:execution_expression] == nil
          raise "options[:expiration_type] is required." if options[:expiration_type] == nil
          body << "&crp=#{options[:rate].to_s}"
          body << "&sjt=#{options[:execution_expression].to_s}"
          body << "&dat=#{options[:expiration_type].to_s}"
          body << "&ykd=" << options[:expiration_date].strftime( "%Y%m%d%H" ) if options[:expiration_date] != nil
        else
          # 成り行き
          path = "/ws/fx/nariyukiKessaiChumon.do"
          if ( options[:slippage] != nil )
            raise "if you use a slippage,  options[:slippage_base_rate] is required." if options[:slippage_base_rate] == nil
            body << "&slp=#{options[:slippage].to_s}&gnp=#{options[:slippage_base_rate].to_s}"
          end
        end
        result = @client.post( @base_uri + path, body)
        doc = ClickClient.parse( result.content )
        elms = doc.get_elements("./*/kessaiChumonList/kessaiChumonListItem")
        if ( elms == nil || elms.length <= 0 )
          elms = doc.get_elements("./*/ocoKessaiChumonList/ocoKessaiChumonListItem")
        end
        return SettleResult.new( elms[0] )
      end

      #
      #=== 建玉一覧を取得します。
      #
      #*currency_pair_code*:: 通貨ペアコード
      #<b>戻り値</b>:: ClickClient::FX::OpenInterestの配列
      #
      def list_open_interests( currency_pair_code=nil )
        body = currency_pair_code != nil ? "tkt=#{currency_pair_code.to_s}" : ""
        result = @client.post( @base_uri + "/ws/fx/tategyokuList.do", body)
        list = []
        doc = ClickClient.parse( result.content )
        doc.elements.each("./tategyokuListResponse/tategyokuList/tategyokuListItem") { |item|
          list << OpenInterest.new( item )
        }
        return list
      end

      #
      #=== 約定一覧を取得します。
      #
      #*from*:: 注文日期間開始日。Dateで指定。例) Date.new(2007, 1, 1)
      #*to*:: 注文日期間終了日。Dateで指定。例) Date.new(2007, 1, 1)
      #*trade_type*:: 取引種別
      #*currency_pair_code*:: 通貨ペアコード
      #<b>戻り値</b>:: ClickClient::FX::ExecutionResultの配列
      #
      def list_execution_results( from, to, trade_type=nil, currency_pair_code=nil )
        raise "from is required." if from == nil
        raise "to is required." if to == nil
        body = "yfd=" << from.strftime( "%Y%m%d" )
        body << "&ytd=" << to.strftime( "%Y%m%d" )
        body << "&tkt=" << currency_pair_code.to_s if currency_pair_code != nil
        body << "&tht=" << trade_type.to_s if trade_type != nil
        result = @client.post( @base_uri + "/ws/fx/yakujoList.do", body)
        list = []
        doc = ClickClient.parse( result.content )
        doc.elements.each("./yakujoListResponse/yakujoList/yakujoListItem") { |item|
          list << ExecutionResult.new( item )
        }
        return list
      end

      #
      #=== 余力情報を取得します。
      #
      #<b>戻り値</b>:: ClickClient::FX::Margin
      #
      def get_margin
        result = @client.post( @base_uri + "/ws/fx/yoryokuJoho.do")
        list = []
        doc = ClickClient.parse( result.content )
        return Margin.new( doc.root )
      end

      #
      #=== お知らせ一覧を取得します。
      #
      #<b>戻り値</b>:: ClickClient::FX::Messageの配列
      #
      def list_messages
        result = @client.post( @base_uri + "/ws/fx/messageList.do")
        list = []
        doc = ClickClient.parse( result.content )
        doc.elements.each("./messageListResponse/messageList/messageListItem") { |item|
          list << Message.new( item )
        }
        return list
      end
    end

    #
    #===通貨ペア
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class CurrencyPair < ClickClient::Base
      def initialize( item )
        super(item)
        @currency_pair_code = item.attributes["tsukaPairCode"].to_i
        @name = item.attributes["tsukaPairName"]
        @max_trade_quantity = item.text( "./maxTorihikiSuryo" ).to_i
        @min_trade_quantity = item.text( "./minTorihikiSuryo" ).to_i
        @trade_unit = item.text( "./torihikiTani" ).to_i
      end
      #通貨ペアコード
      attr :currency_pair_code, true
      #名前
      attr :name, true
      #最大取引数量
      attr :max_trade_quantity, true
      #最低取引数量
      attr :min_trade_quantity, true
      #取引単位
      attr :trade_unit, true
    end

    #
    #
    #===レート
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class Rate < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
        super(item)
        @currency_pair_code = item.get_elements("./tsukaPair")[0].attributes["tsukaPairCode"].to_i
        @bid_rate = item.text( "./bid" ).to_f
        @ask_rate = item.text( "./ask" ).to_f
        @day_before_to = item.text( "./zenjitsuhi" ).to_f
        @bid_high = item.text( "./bidHigh" ).to_f
        @bid_low = item.text( "./bidLow" ).to_f
        @buy_swap = item.text( "./kaiSwap" ).to_i
        @sell_swap = item.text( "./uriSwap" ).to_i
        @date = DateTime.strptime( item.text( "./hasseibi" ), "%Y-%m-%d")
        @days_of_grant = item.text( "./fuyoNissu" ).to_i
      end
      #通貨ペアコード
      attr :currency_pair_code, true
      #Bidレート
      attr :bid_rate, true
      #Askレート
      attr :ask_rate, true
      #前日終値比。現在のBidレートと直近のNYクローズ時のBidレートとの差。
      attr :day_before_to, true
      #Bidレート高値
      attr :bid_high, true
      #Bidレート安値 
      attr :bid_low, true
      #買スワップポイント（円）
      attr :buy_swap, true
      #売スワップポイント（円）
      attr :sell_swap, true
      #発生日
      attr :date, true
      #付与日数
      attr :days_of_grant, true
    end

    #
    #===注文
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class Order < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
        super(item)
        @order_no = item.attributes["chumonBango"].to_i
        @enable_change_or_cancel = item.text( "./henkoTorikeshiKano" ).to_i == 1
        @trade_type = item.text( "./torihiki" ).to_i
        @sell_or_buy = item.text( "./baibai" ).to_i
        @trade_quantity = item.text( "./hatchuSuryo" ).to_i
        @rate = item.text( "./chumonRate" ).to_f
        @execution_expression = item.text( "./shikko" ).to_i
        @date = DateTime.strptime( item.text( "./hatchuNichiji" ), "%Y-%m-%d %H:%M:%S")
        @expiration_type = item.text( "./yukoKigen" ).to_i

        str = item.text( "./yukoNichiji" )
        @expiration_date = str != nil ? DateTime.strptime( str , "%Y-%m-%d %H:%M:%S") : nil

        @order_state = item.text( "./chumonJotai" ).to_i
        @failure_reason = item.text( "./fuseiritsuRiyu" ).to_i

        str = item.text( "./yakujoRate" )
        @settlement_rate = str != nil  ? str.to_f : nil

        str = item.text( "./yakujoNichiji" )
        @settlement_date = str != nil ? DateTime.strptime( str , "%Y-%m-%d %H:%M:%S") : nil

      end
      #注文番号
      attr :order_no, true
      #注文の変更および取消が可能かどうか
      attr :enable_change_or_cancel, true
      #注文時の取引種類
      attr :trade_type, true
      #売買区分
      attr :sell_or_buy, true
      #取引数量
      attr :trade_quantity, true
      #レート。執行条件が「成行」の場合は約定レートと同値。
      attr :rate, true
      #執行条件
      attr :execution_expression, true
      #注文を受け付けた日時
      attr :date, true
      #注文時に指定した有効期限種別
      attr :expiration_type, true
      #注文時に有効期限を日時指定した場合の、日時
      attr :expiration_date, true
      #注文状態
      attr :order_state, true
      #不成立理由
      attr :failure_reason, true
      #約定レート。注文が不成立の場合はnil
      attr :settlement_rate, true
      #約定日時。注文が不成立の場合はnil
      attr :settlement_date, true
    end

    #
    #===注文結果
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class OrderResult < ClickClient::Base

      #
      #===コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
        super(item)
        str = item.text( "./chumonBango")
        if str == nil || str.length <= 0
          str = item.text( "./shinkiChumonBango")
        end
        @order_no = str != nil ? str.to_i : nil
        str = item.text( "./kessaiChumonBango" )
        @settlement_order_no = str != nil ? str.to_i : nil
        str = item.text( "./tategyokuBango" )
        @open_interest_no = str != nil ? str.to_i : nil

        str = item.text( "./sashineChumonBango" )
        @limit_order_no = str != nil ? str.to_i : nil
        str = item.text( "./gyakusashiChumonBango" )
        @stop_order_no = str != nil ? str.to_i : nil

      end
      #注文番号
      attr :order_no, true
      #建玉番号
      attr :open_interest_no, true
      #決済注文番号(IFD, IFD-OCO取引のみ)
      attr :settlement_order_no, true
      #指値注文番号(OCO取引のみ)
      attr :limit_order_no, true
      #逆指値注文番号(OCO取引のみ)
      attr :stop_order_no, true
    end

    #
    #===決済注文結果
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class SettleResult < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
        super(item)
        str = item.text( "./chumonBango")
        @settlement_order_no = str != nil ? str.to_i : nil
        str = item.text( "./kessaiTategyokuBango" )
        @open_interest_no = str != nil ? str.to_i : nil

        str = item.text( "./sashineChumonBango" )
        @limit_settlement_order_no = str != nil ? str.to_i : nil
        str = item.text( "./gyakusashiChumonBango" )
        @stop_settlement_order_no = str != nil ? str.to_i : nil
      end
      #決済注文番号
      attr :settlement_order_no, true
      #建玉番号
      attr :open_interest_no, true
      #決済指値注文番号(OCO取引のみ)
      attr :limit_settlement_order_no, true
      #決済逆指値注文番号(OCO取引のみ)
      attr :stop_settlement_order_no, true
    end

    #
    #===建玉
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class OpenInterest < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
         super(item)
         @currency_pair_code = item.get_elements("./tsukaPair")[0].attributes["tsukaPairCode"].to_i
      end
      #通貨ペアコード
      attr :currency_pair_code, true
    end

    #
    #===約定
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class ExecutionResult < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
         super(item)
         @currency_pair_code = item.get_elements("./tsukaPair")[0].attributes["tsukaPairCode"].to_i
      end
      #通貨ペアコード
      attr :currency_pair_code, true
    end

    #
    #===余力
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class Margin < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
        super(item)
        @margin = item.text( "./yoryoku").to_i
        @transferable_money_amount = item.text( "./furikaeKano" ).to_i
        @guarantee_money_status = item.text( "./shokokinStatus" ).to_i
        @guarantee_money_maintenance_ratio = item.text( "./shokokinIjiritsu" ).to_f
        @market_value = item.text( "./jikaHyokaSogaku" ).to_i
        @appraisal_profit_or_loss_of_open_interest = item.text( "./tategyokuHyokaSoneki" ).to_i
        @balance_in_account = item.text( "./kozaZandaka" ).to_i
        @balance_of_cach = item.text( "./genkinZandaka" ).to_i
        @settlement_profit_or_loss_of_today = item.text( "./kessaiSonekiT" ).to_i
        @settlement_profit_or_loss_of_next_business_day = item.text( "./kessaiSonekiT1" ).to_i
        @settlement_profit_or_loss_of_next_next_business_day = item.text( "./kessaiSonekiT2" ).to_i
        @swap_profit_or_loss = item.text( "./swapSoneki" ).to_i
        @freezed_guarantee_money = item.text( "./kosokuShokokin" ).to_i
        @required_guarantee_money = item.text( "./hitsuyoShokokin" ).to_i
        @ordered_guarantee_money = item.text( "./chumonShokokin" ).to_i

        @guarantee_money_list = []
        item.elements.each( "./torihikiShokokinList/torihikiShokokinListItem" ) { |t|
          @guarantee_money_list << GuaranteeMoney.new(t)
        }
      end
      #余力
      attr :margin, true
      #振替可能額
      attr :transferable_money_amount, true
      #証拠金ステータス
      attr :guarantee_money_status, true
      #証拠金の維持率
      attr :guarantee_money_maintenance_ratio, true
      #時価評価の総額
      attr :market_value, true
      #建玉の評価損益
      attr :appraisal_profit_or_loss_of_open_interest, true
      #口座残高
      attr :balance_in_account, true
      #現金残高
      attr :balance_of_cach, true
      #当日既決済取引の損益
      attr :settlement_profit_or_loss_of_today, true
      #翌営業日既決済取引の損益
      attr :settlement_profit_or_loss_of_next_business_day, true
      #翌々営業日既決済取引の損益
      attr :settlement_profit_or_loss_of_next_next_business_day, true
      #スワップ損益
      attr :swap_profit_or_loss, true
      #拘束されている証拠金
      attr :freezed_guarantee_money, true
      #必要な証拠金
      attr :required_guarantee_money, true
      #注文中の証拠金
      attr :ordered_guarantee_money, true
      #証拠金一覧(ClickClient::FX::GuaranteeMoneyの配列)
      attr :guarantee_money_list, true
    end

    #
    #===証拠金
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、クリック証券提供のドキュメントを参照ください。
    #
    class GuaranteeMoney < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
         super(item)
         @currency_pair_code = item.attributes["tsukaPairCode"].to_i
         @guarantee_money = item.text( "./torihikiShokokin" ).to_i
      end
      #通貨ペアコード
      attr :currency_pair_code, true
      #証拠金
      attr :guarantee_money, true
    end

    #
    #===お知らせ
    #
    #定義済みの属性の他に、レスポンスXMLの要素名、属性名でも値にアクセスできます。
    #レスポンスXMLについては、ClickClientインターネット証券提供のドキュメントを参照ください。
    #
    class Message < ClickClient::Base

      #
      #=== コンストラクタ
      #
      #*item*:: 結果要素
      #
      def initialize( item )
        super(item)
        @title = item.text( "./title" )
        @text  = item.text( "./text" )
      end
      #タイトル
      attr :title, true 
      #本文
      attr :text, true
    end
  end

end
