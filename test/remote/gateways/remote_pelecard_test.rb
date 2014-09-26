require 'test_helper'

class RemotePelecardTest < Test::Unit::TestCase
  def setup
    @gateway = PelecardGateway.new(fixtures(:pelecard))

    @amount = 1000
    @credit_card = credit_card('4557440410955907', { :month => 1,
        :year => Time.now.year + 3,
        :first_name => 'Test',
        :last_name => 'Test',
        :verification_value => '333',
        :brand => 'master' })
    @declined_card = credit_card('40003020A')
    @token = '1785930294'
    @declined_token = '323741AV00'
    @options = {
      id: "123456789"
    }
  end

  def test_successful_purchase_card
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'success', response.message
  end

  def test_successful_purchase_token
    response = @gateway.purchase(@amount, @token, @options)
    assert_success response
    assert_equal 'success', response.message
  end

  def test_failed_purchase_card
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'invalid card number', response.message
  end

  def test_failed_purchase_token
    response = @gateway.purchase(@amount, @declined_token, @options)
    assert_failure response
    assert_equal 'invalid token number', response.message
  end

  def test_successful_authorize_card
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal "5", response.params["J"]
  end

  def test_successful_authorize_token
    auth = @gateway.authorize(@amount, @token, @options)
    assert_success auth
    assert_equal "5", response.params["J"]
  end

  def test_failed_authorize_card
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
  end

  def test_failed_authorize_token
    response = @gateway.authorize(@amount, @declined_token, @options)
    assert_failure response
  end

  def test_successful_refund_card
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, @credit_card, @options)
    assert_success refund
  end

  def test_partial_refund_card
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 100, @credit_card, @options)
    assert_success refund
  end

  def test_failed_refund_card
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_raise_with_message(ArgumentError, "Money should be a positive integer in cents") do
      @gateway.refund(-1000, @credit_card, @options)
    end
  end

  def test_successful_refund_token
    purchase = @gateway.purchase(@amount, @token, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, @token, @options)
    assert_success refund
  end

  def test_partial_refund_token
    purchase = @gateway.purchase(@amount, @token, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 100, @token, @options)
    assert_success refund
  end

  def test_failed_refund_token
    purchase = @gateway.purchase(@amount, @token, @options)
    assert_success purchase
    assert_raise_with_message(ArgumentError, "Money should be a positive integer in cents") do
      @gateway.refund(-1000, @token, @options)
    end
  end

  def test_successful_check_login
    response = @gateway.check_login
    assert_success response
  end

  def test_failed_check_login
    bad_gateway = PelecardGateway.new(login: "Bogus", password: "Bogus", terminal_no: "1234567")
    response = bad_gateway.check_login
    assert_failure response
  end

  def test_successful_get_error_message
    response = @gateway.get_error_message("000")
    assert_success response
  end

  def test_failed_get_error_message
    bad_gateway = PelecardGateway.new(login: "Bogus", password: "Bogus", terminal_no: "1234567")
    response = bad_gateway.get_error_message("000")
    assert_failure response
  end

  # def test_successful_void
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert void = @gateway.void(auth.authorization)
  #   assert_success void
  # end

  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  # end

  # def test_successful_verify
  #   response = @gateway.verify(@credit_card, @options)
  #   assert_success response
  #   assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  # end

  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end

  # def test_invalid_login
  #   gateway = PelecardGateway.new(
  #     login: '',
  #     password: ''
  #   )
  #   response = gateway.purchase(@amount, @credit_card, @options)
  #   assert_failure response
  # end
end
