begin
  require 'rubygems'
rescue LoadError
end
require 'httpclient'
require 'rexml/document'
require 'date'

#
#=== クリック証券アクセスクライアント
#
#*Version*::   0.0.2
#*License*::   Ruby ライセンスに準拠
#
#クリック証券Webサービスを利用するためのクライアントライブラリです。以下の機能を提供します。
#- 外為証拠金取引(FX)取引
#
#====依存モジュール
#「{httpclient}[http://dev.ctor.org/http-access2]」を利用しています。以下のコマンドを実行してインストールしてください。
#
# gem install httpclient --source http://dev.ctor.org/download/
#
#====基本的な使い方
#
# require 'clickclient'
# 
# c = ClickClient::Client.new 
# # c = ClickClient::Client.new https://<プロキシホスト>:<プロキシポート> # プロキシを利用する場合
# c.fx_session( "<ユーザー名>", "<パスワード>" ) { | fx_session |
#   # 通貨ペア一覧取得
#   list = fx_session.list_currency_pairs
#   puts list
# } 
#なお、ご利用にあたっては「{クリック証券Ｗｅｂサービス利用規約}[https://sec.gmo.jp/corp/guide/regulations/pdf/reg_webservice.pdf]
#」(PDF)に同意して頂く必要があります。
#
#====免責
#- 本ライブラリの利用は自己責任でお願いします。
#- ライブラリの不備・不具合等によるあらゆる損害について、作成者は責任を負いません。
#
module ClickClient
  
  # クライアント
  class Client

    # ホスト名
    DEFAULT_HOST_NAME = "https://sec-sso.click-sec.com"

    #
    #===コンストラクタ
    #
    #*proxy*:: プロキシホストを利用する場合、そのホスト名とパスを指定します。
    # 例) https://proxyhost.com:80
    #
    def initialize( proxy=nil  )
      @client = HTTPClient.new( proxy, "ClickClientLib")
      @client.set_cookie_store("cookie.dat")
      @host_name = DEFAULT_HOST_NAME
    end
    
    #ホスト名
    attr :host_name, true
    
  private
    # ログインしてブロックを実行する。ブロックの実行後ログアウトする。
    def session( uri, userid, password, &block )

      # sequence 1
      result = @client.post(uri, "u=" << userid )
      seq2_uri = result.header["Location"].to_s
      raise "fail session-1.responce=" << result.content  if seq2_uri == nil  || seq2_uri.length <= 0

      # sequence 2
      result = @client.get( seq2_uri )
      doc = REXML::Document.new(result.content)
      unless ( doc.text( "./loginResponse/responseStatus" ) =~ /OK/  )
        raise "fail session-2." << doc.text( "./loginResponse/message" )
      end

      # sequence 3
      base_uri = File.dirname( seq2_uri  )
      result = @client.post(  base_uri  +  "/ws-login", "j_username=#{userid}&j_password=#{password}" )
      seq4_uri = result.header["Location"]
      if ( seq4_uri == nil  || seq4_uri.length <= 0 )
        doc = REXML::Document.new(result.content)
        raise "fail session-3." << doc.text( "./loginResponse/message" )
      end

      # sequence 4
      # responseStatusがOKになるまでリダイレクトが続く。
      while ( true )
        result = @client.get( seq4_uri )
        doc = REXML::Document.new(result.content)
        if ( doc.text( "./loginResponse/responseStatus" ) =~ /OK/  )
          break
        else
          seq4_uri = result.header["Location"]
          raise "fail session-4.responce=" << result.content  if seq4_uri == nil  || seq4_uri.length <= 0
        end
      end

      begin
        block.call( @client, base_uri )
      ensure
        # logout
        result = @client.post(  base_uri  +  "/ws-logout" )
        doc = REXML::Document.new(result.content)
        unless ( doc.text( "./logoutResponse/responseStatus" ) =~ /OK/  )
          raise "fail session-5." << doc.text( "./logoutResponse/message" )
        end
      end

    end
  end

private

  #
  #=== 結果オブジェクトの抽象基底クラス。
  #
  class Base #:nodoc:
    def initialize( item )
      # 属性と子要素の値を、オブジェクトの属性として格納する。
      item.attributes.each { |name, value|
        set_attribute(name.to_s ,value)
      }
      item.elements.each { |elm|
        if ( elm.name != "responseStatus" && elm.name != "message" )
          set_attribute(elm.name.to_s, elm.text)
        end
      }
    end
    def to_s
      str = ""
      instance_variables.each { |name|
        str += name + "=" + instance_variable_get(name).to_s + ", "
      }
      return str.chop.chop
    end
    def method_missing( name, *args )
      if name.to_s =~ /(.*?)=/
        name = $1
        setter = true
      end
      
      # 同名の属性があればそれのReaderと見なし、属性値を返す。
      value = instance_variable_get("@" << name.to_s)
      unless ( value == nil )
        if setter
          instance_variable_set( "@" << name, args[0] )
        else
          return value
        end
      else
        super(name)
      end
    end
    def hash 
      hash = 0
      values.each {|v|
        hash = v.hash + 31 * hash
      }
      return hash
    end
    def eql?(other)
      return false if other == nil 
      return false unless other.is_a?( Base )
      a = values
      b = other.values
      return false if a.length != b.length
      a.length.times{|i|
        return false unless a[i].eql? b[i]
      }
      return true
    end
  protected
    def values
      values = []
      instance_variables.each { |name|
        values << instance_variable_get(name)
      }
      return values
    end
  private
    def set_attribute(name ,value)
      if ( value =~  /^\d+$/)
        value = value.to_i
      elsif ( value =~  /^[\d\.]+$/)
        value = value.to_f
      elsif ( value =~ /^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$/)
        value = DateTime.strptime( value, "%Y-%m-%d %H:%M:%S")
      elsif ( value =~ /^\d{4}-\d{2}-\d{2}$/)
        value = DateTime.strptime( value, "%Y-%m-%d")
      end
      instance_variable_set( "@" << name, value )
    end
  end

  # 結果を解析し、エラーであれば例外をスローする。
  def self.parse( content )
    doc = REXML::Document.new( content )
    unless ( doc.text( "./*/responseStatus" ) =~ /OK/  )
      raise "fail." << doc.text( "./*/message" )
    end
    return doc
  end

end
