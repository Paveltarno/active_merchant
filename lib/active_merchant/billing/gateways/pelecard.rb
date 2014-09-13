module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # Gateway adapter for Pelecard
    # for every function, if a token parameter is sent through
    # the payment parameter can be a credit card or a token
    class PelecardGateway < Gateway
      # Consts
      DEFAULT_SHOP_NO = '1'
      ACTIONS_MAP = {
        "sale" => "DebitRegularType",
        "authonly" => "AuthrizeCreditCard",
        "refund" => "DebitRegularType"
      }

      self.test_url = 'https://ws101.pelecard.biz/webservices.asmx'
      self.live_url = 'https://ws101.pelecard.biz/webservices.asmx'

      self.supported_countries = ['IL']
      self.default_currency = 'ILS'
      self.supported_cardtypes = [:visa, :master, :american_express]

      self.homepage_url = 'http://www.pelecard.com'
      self.display_name = 'Pelecard Gateway'

      # TODO: The amount should be in cents
      def initialize(options={})
        requires!(options, :login, :password, :terminal_no)
        options[:shop_no] = DEFAULT_SHOP_NO unless options.has_key?(:shop_no) 
        super
      end

      def purchase(money, payment, options={})
        requires!(options, :id)
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      # def capture(money, authorization, options={})
      #   commit('capture', post)
      # end

      # def refund(money, authorization, options={})
      #   commit('refund', post)
      # end

      # def void(authorization, options={})
      #   commit('void', post)
      # end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      private

      def add_customer_data(post, options)
        post[:id] = options[:id]
      end

      # Money is in cents
      def add_invoice(post, money, options)
        post[:total] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
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

      def parse(body)
        binding.pry
        {}
      end

      def commit(action, parameters)
        url = build_url(action)
        response = parse(ssl_post(url, post_data(action, parameters)))
        
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
      end

      def message_from(response)
      end

      def authorization_from(response)
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
          when "authorize"
            keys = [:creditCard, :creditCardDateMmyy, :token, :total, :currency, :cvv2, :id, :parmx]
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

    end

  end
end
