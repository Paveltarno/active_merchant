# !!!This is a gateway for testing only!!!
# TODO : Remove if not needed
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # Gateway adapter for Pelecard
    # for every function, if a token parameter is sent through
    # the payment parameter can be a credit card or a token
    class PelecardBogusGateway < PelecardGateway
      # Consts
      STUB_PELE_FAIL = "0030000455744******590722000501170000000000 000000001011 150 52000000000000000000000000097001065 „† „†‰…0"
      STUB_PELE_SUCCESS = "0000000455744******590722000501170000000000 000000001011 150 52000000000000000000000000097001065 „† „†‰…0"

      self.test_url = 'https://ws101.pelecard.biz/webservices.asmx'
      self.live_url = 'https://ws101.pelecard.biz/webservices.asmx'

      def test?
        true
      end

      def parse(body, &block)
        parse_int_ot(body, &block)
      end

      private

      def commit(action, parameters)
        url = build_url(action)

        # Create data for post
        data = post_data(action, parameters)
        response = parse(post_stub(action, parameters))
        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def post_stub(action, parameters)
        fail = parameters[:stub_fail]
        auth_code = Random.new.rand(1000000..9999999).to_s
        int_ot = fail ? STUB_PELE_FAIL : STUB_PELE_SUCCESS
        int_ot[70..76] = auth_code
        return int_ot
      end

    end

  end
end
