module Stripe::Model
  class Error < ::RuntimeError ; end
  class MissingModelFields < Error ; end
  
  def self.included(base)
    if Object.const_defined?(:Mongoid) && base.included_modules.include?(Mongoid::Document)
      base.field :subscription_coupon_code
      base.field :subscription_customer_id
      base.field :subscription_status
      base.field :subscription_ends_at, :type => Time
      base.field :credit_card_type
      base.field :credit_card_number
      base.field :credit_card_expires_on, :type => Date
    else
      required_fields = %w(
        subscription_customer_id subscription_status subscription_ends_at subscription_coupon_code
        credit_card_type credit_card_number credit_card_expires_on
      )

      instance = base.new
      required_fields.each do |field| 
        unless instance.respond_to?(field)
          msg = "WARN: Missing required model field: #{field}. stripe-rails will not work properly without it."
          base.logger.warn msg
          puts msg
        end
      end
    end

    base.send :attr_accessor, :credit_card_token
    base.before_create :subscription_create
    base.before_update :subscription_update
    
    base.extend ClassMethods
  end

  module ClassMethods
    def subscription_event(params)
      user = where(:subscription_customer_id => params[:customer]).first
      if params[:event] == "recurring_payment_succeeded"
        # TODO: Do I need to set subscription_ends_at to invoice/lines/subscriptions[0]/period/end or invoice/period_end
        user.update_attributes! :subscription_status => "active", :subscription_ends_at => Time.at(params[:invoice][:period_end])
      elsif params[:event] == "subscription_final_payment_attempt_failed"
        # TODO: Do I need to set subscription_ends_at to canceled_at or ended_at?
        user.update_attributes! :subscription_status => params[:subscription][:status]
      end
    end
  end

  def subscription_reactivate!
    customer = Stripe::Customer.retrieve(subscription_customer_id)
    trial_end_at = subscription_ends_at > Time.now ? subscription_ends_at : nil
    customer.update_subscription(:plan => STRIPE_PLAN_ID, :trial_end => trial_end_at.to_i)
    update_attributes! :subscription_status => customer.subscription.status, :subscription_ends_at => Time.at(customer.subscription.current_period_end)
  end

  def subscription_cancel!
    customer = Stripe::Customer.retrieve(subscription_customer_id)
    customer.cancel_subscription(:at_period_end => true)
    # TODO: Do I need to set subscription_ends_at to canceled_at or ended_at or current_period_end
    update_attributes! :subscription_status => "canceled"
  end
  
  def subscription_valid?
    # NOTE: Stripe billing may not be complete by the subscription_ends_at time. Pad this check with an hour to ensure everything works properly.
    # TODO: Change all this to DATES?
    subscription_ends_at >= 1.hour.ago
  end
  
  def subscription_active?
    subscription_status == "trialing" || subscription_status == "active"
  end

  def subscription_canceled?
    subscription_status == "canceled"
  end
  
private
  def subscription_create
    params = {
      :plan => STRIPE_PLAN_ID,
      :trial_end => STRIPE_TRIAL_PERIOD.from_now.to_i,
      :description => email,
      :email => email
    }
    params[:coupon] = subscription_coupon_code if subscription_coupon_code.present?
    customer = Stripe::Customer.create(params)

    self.subscription_customer_id = customer.id
    self.subscription_status = customer.subscription.status
    self.subscription_ends_at = Time.at(customer.subscription.current_period_end)
  rescue Stripe::InvalidRequestError => e
    errors[:base] << e.message
    false
  end

  def subscription_update
    if attribute_changed?("email") or credit_card_token.present?
      customer = Stripe::Customer.retrieve(subscription_customer_id)
      customer.description = email
      customer.email = email
      customer.card = credit_card_token
      customer.save

      self.credit_card_type = customer.active_card.type
      self.credit_card_number = customer.active_card.last4
      self.credit_card_expires_on = Date.new(customer.active_card.exp_year, customer.active_card.exp_month).end_of_month
    end
  rescue Stripe::InvalidRequestError => e
    # TODO: This error never makes it back to the user
    errors[:base] << e.message
    false
  end
end