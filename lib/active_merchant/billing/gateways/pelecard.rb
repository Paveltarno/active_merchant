module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # Gateway adapter for Pelecard
    # for every function, if a payment parameter is sent through
    # its parameter can be a credit card object or a token strubg
    class PelecardGateway < Gateway
      # Consts
      DEFAULT_SHOP_NO = '1'
      PARMX_MAX_CHAR_NUM = 19
      ACTIONS_MAP = {
        "sale" => "DebitRegularType",
        "authonly" => "AuthrizeCreditCard",
        "refund" => "DebitRegularType",
        "check_login" => "GetRetNum",
        "check_error" => "CheckError"
      }
      RETURN_CODE_SUCCESS = "000"
      RETURN_CODES = {
        RETURN_CODE_SUCCESS => "success",
        "003" => "contact credit company",
        "033" => "invalid card number",
        "039" => "invalid card number",
        "036" => "card expired",
        "004" => "card declined",
        "005" => "fake card",
        "006" => "invalid id or cvv",
        "014" => "unsupported card type",
        "044" => "terminal not allowed to authorize only (J5)",
        "065" => "invalid currency",
        "434" => "invlaid terminal number",
        "501" => "invalid userName/password combination",
        "502" => "password expired",
        "503" => "terminal user is locked",
        "506" => "invalid token number"
      }

      # D.M
      self.test_url = 'https://ws101.pelecard.biz/webservices.asmx'
      self.live_url = 'https://ws101.pelecard.biz/webservices.asmx'

      self.supported_countries = ['IL']
      self.default_currency = '1' # ILS
      self.supported_cardtypes = [:visa, :master, :american_express]
      self.money_format = :cents

      self.homepage_url = 'http://www.pelecard.com'
      self.display_name = 'Pelecard Gateway'

      # TODO: The amount should be in cents
      def initialize(options={})
        requires!(options, :login, :password, :terminal_no)
        options[:shop_no] = DEFAULT_SHOP_NO unless options.has_key?(:shop_no)
        options[:use_pelecard_messages] = options.has_key?(:use_pelecard_messages) ? options[:use_pelecard_messages] : true
        super
      end

      def purchase(money, payment, options={})
        exec_action(money, payment, "sale", options)
      end

      def authorize(money, payment, options={})
        exec_action(money, payment, "authonly", options)
      end

      def capture(money, authorization, options={})
        requires!(options, :token)
        options[:authNum] ||= authorization
        exec_action(money, options[:token], "sale", options)
      end

      def refund(money, payment, options={})
        options[:refund] = true
        exec_action(money, payment, "sale", options)
      end

      #
      # Get pelecards error message for the given code
      #
      # @param [String] error_code Error code
      #
      # @return [String] Error message
      # 
      def get_error_message(error_code)
        action = "check_error"
        url = build_url(action)

        # Create data for post
        data = post_data(action, { code: error_code })

        # The result should be a test message or and error code
        response = parse(ssl_post(url, data)) { |raw| { message: raw } }
        success = response[:message].length > 3
        Response.new(
          success,
          response[:message],
          response,
          authorization: "",
          test: test?
        )
      end

      #
      # Checks the credentials using pelecards service
      #
      #
      # @return [<type>] <description>
      # 
      def check_login
        action = "check_login"
        url = build_url(action)

        # Create data for post
        data = post_data(action)

        # The raw should be the terminal number on success
        response = parse(ssl_post(url, data)) { |raw| { code: raw[0..6] } }
        success = response[:code] == @options[:terminal_no] ? true : false
        Response.new(
          success,
          "",
          response,
          authorization: "",
          test: test?
        )
      end

      def parse(body, &block)
        raw = REXML::Document.new(body).root.text

        parse_int_ot(raw, &block)
      end

      #
      # Parses the response from the pelecard service
      # specifications can be found at: 
      # http://mabat.net/572/documents/Iframe%20mobile%20-%20Payment/Iframe_CSS_Friendly_-_Programmer_Manual_-_English.pdf
      # 
      # @param [<string>] body <response from server>
      # @param [<block>] block <optional custom parse>
      #
      # @return [<hash>] <parsed response>
      # 
      def parse_int_ot(int_ot, &block)
        if block_given?
          block.call(int_ot)
        else
          response = {}
          response[:response_code] = int_ot[0..2]
          response[:card_number] = int_ot[4..22]
          response[:last_digits] = int_ot[19..22]
          response[:card_brand] = int_ot[23]
          response[:credit_firm] = int_ot[24]
          response[:J] = int_ot[28]
          response[:exp_MMYY] = int_ot[29..32]
          response[:id_response] = int_ot[33]
          response[:cvv_result] = int_ot[34]
          response[:amount_cents] = int_ot[35..42]
          response[:credit_issuer] = int_ot[60]
          response[:authorization_number] = int_ot[70..76]
          response[:parmx] = int_ot[119..137]
          response
        end
      end

      # TODO: Clean up all the commented out

      # def void(authorization, options={})
      #   commit('void', post)
      # end

      # def verify(credit_card, options={})
      #   MultiResponse.run(:use_first_response) do |r|
      #     r.process { authorize(100, credit_card, options) }
      #     r.process(:ignore_result) { void(r.authorization, options) }
      #   end
      # end

      private

      # For keeping our code DRY
      def exec_action(money, payment, action, options={})
        raise ArgumentError, "Money should be a positive integer in cents" if money < 0 
        raise ArgumentError, "Payment should be a token string or a CreditCard object" if !payment
        requires!(options, :id)
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)
        add_parmx(post, options)

        commit(action, post)
      end

      def add_customer_data(post, options)
        post[:id] = options[:id]
      end

      # Money is in cents
      def add_invoice(post, money, options)
        post[:total] = amount(money, options.include?(:refund))
        post[:currency] = (options[:currency] || currency(money))
        post[:authNum] ||= options[:authNum]
      end

      # Adds token data or credit card
      def add_payment(post, payment)
        case payment
        when String
          post[:token] = payment
        when CreditCard
          post[:creditCard] = payment.number
          post[:creditCardDateMmyy] = expdate(payment)
          post[:cvv2] = payment.verification_value
        end
      end

      def add_parmx(post, options)
        post[:parmx] ||= options[:parmx]
      end

      def commit(action, parameters)
        url = build_url(action)

        # Create data for post
        data = post_data(action, parameters)
        response = parse(ssl_post(url, data))
        
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:response_code] == RETURN_CODE_SUCCESS
      end

      def message_from(response)
        code = response[:response_code]
        message = nil

        # Check if pelecard messages should be retrieved
        message = message_from_pelecard(code) if @options[:use_pelecard_messages] == true
          
        # if message is nil
        if !message
          message = RETURN_CODES.include?(code) ? RETURN_CODES[code] : "Irregular response code (#{code})"
        end

        return message
      end

      def message_from_pelecard(response_code)
        get_message_reponse = get_error_message(response_code)
        message = nil
        message = "#{get_message_reponse.message} (#{response_code})" if get_message_reponse.success?
      end

      def authorization_from(response)
        response[:authorization_number]
      end

      # Pelecard requires that all parameters will be sent
      # for each action even if they are empty
      # the specifications can be found here:
      # http://mabat.net/572/documents/WebService/WebService_Eng.htm
      # this function initializes the final post data hash
      #
      # @param [<String>] action <Init params for this action>
      # @param [<Hash>] parameters <The params >
      #
      # @return [<Hash>] <An initialised hash>
      # 
      def post_data(action, parameters = {})

        # Init default hash
        keys = []

        # Create the data hash with mendatory fields
        data = { userName: @options[:login],
          password: @options[:password],
          termNo: @options[:terminal_no],
          shopNo: @options[:shop_no] }

        # Merge the params into the final hash
        data.merge!(parameters)

        # Check action
        case action
          when "sale"
            keys = [:creditCard, :creditCardDateMmyy, :token, :total, :currency, :cvv2, :id, :authNum,
              :parmx]
          when "authonly"
            keys = [:creditCard, :creditCardDateMmyy, :token, :total, :currency, :cvv2, :id, :parmx]
          when "check_error"
            keys = [:code]
          when "check_login"
            keys = []
        else
          raise ArgumentError, "Action: #{action} is not supported"
        end
        
        # Ensure all fields are inserted. If not create them blank
        keys.each { |x| check_or_create_for!(data, x) }

        # Turn the hash into a string
        data.collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end

      # Checks if the key exists, if not
      # creates it with an empty string as a value
      def check_or_create_for!(hash, key)
        hash[key] = "" unless hash.include?(key)
      end

      def expdate(creditcard)
        year  = format(creditcard.year, :two_digits)
        month = format(creditcard.month, :two_digits)

        "#{month}#{year}"
      end

      def build_url(action)
        base_url = (test? ? test_url : live_url)
        raise ArgumentError, "Action: #{action} cannot be mapped to URI" unless ACTIONS_MAP.include?(action)
        "#{base_url}/#{ACTIONS_MAP[action]}"
      end

      #
      # Overloads the regular amount
      #
      def amount(money, negative = false)
        return nil if money.nil?
        cents = if money.respond_to?(:cents)

          # TODO: Check with new version of gateway
          ActiveMerchant.deprecated "Support for Money objects is deprecated and will be removed from a future release of ActiveMerchant. Please use an Integer value in cents"
          money.cents
        else
          money
        end

        if negative
          # Negate it
          cents = -cents
        end

        if money.is_a?(String)
          raise ArgumentError, 'money amount must be an Integer in cents.'
        end

        if self.money_format == :cents
          cents.to_s
        else
          sprintf("%.2f", cents.to_f / 100)
        end
      end

    end

  end
end
