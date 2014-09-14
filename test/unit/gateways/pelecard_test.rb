require 'test_helper'

class PelecardTest < Test::Unit::TestCase
  def setup
    @gateway = PelecardGateway.new(
      login: 'login',
      password: 'password',
      terminal_no: '12345'
    )

    @credit_card = credit_card
    @token = '1477499800'
    @amount = 100

    @options = {
      id: "1234567"
    }
  end

  def test_successful_purchase_card
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  def test_successful_purchase_token
    @gateway.expects(:ssl_post).returns(successful_purchase_token_response)

    response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert response.test?
  end

  # def test_failed_purchase
  #   @gateway.expects(:ssl_post).returns(failed_purchase_response)

  #   response = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_aut_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
  end

  # def test_failed_authorize
  # end

  # def test_successful_capture
  # end

  # def test_failed_capture
  # end

  # def test_successful_refund
  # end

  # def test_failed_refund
  # end

  # def test_successful_void
  # end

  # def test_failed_void
  # end

  # def test_successful_verify
  # end

  # def test_successful_verify_with_failed_void
  # end

  # def test_failed_verify
  # end

  # private

  def successful_purchase_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<string xmlns=\"https://ws101.pelecard.biz/\">0000000532610035128471011000409153300000100        000000001011 150  0000000000000000000000000073001062 \xC6\x92\xCB\x9C\xE2\x80\x94\xCB\x9C\xCB\x86\xE2\x80\x98\xC2\x8E/\xE2\x80\x9E\xC2\x90\xE2\x80\xB0\xCB\x86\xC2\x8C\xE2\x80\x9D0                   \r\n</string>"
  end

  def successful_purchase_token_response
    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<string xmlns=\"https://ws101.pelecard.biz/\">0000000532610******471011000404173000000100        000000001011 150  0000000000000000000000000073001083 \xC6\x92\xCB\x9C\xE2\x80\x94\xCB\x9C\xCB\x86\xE2\x80\x98\xC2\x8E/\xE2\x80\x9E\xC2\x90\xE2\x80\xB0\xCB\x86\xC2\x8C\xE2\x80\x9D0                   \r\n</string>"
  end

  # def failed_purchase_response
  # end

  def successful_authorize_response
  end

  def failed_authorize_response
  end

  # def successful_capture_response
  # end

  # def failed_capture_response
  # end

  # def successful_refund_response
  # end

  # def failed_refund_response
  # end

  # def successful_void_response
  # end

  # def failed_void_response
  # end

  def check_uri_build

  end
end
