# config/initializers/stripe.rb

    require 'stripe/model'

    if Rails.env.production?
      Stripe.api_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      STRIPE_PUBLISHABLE_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    else
      Stripe.api_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      STRIPE_PUBLISHABLE_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
    end

    STRIPE_PLAN_ID = "some-awesome-plan"
    STRIPE_TRIAL_PERIOD = 1.month



# app/controllers/stripe_controller.rb

    class StripeController < ApplicationController
      def webhook
        Account.subscription_event(params)
        head :ok
      end
    end



# app/controllers/accounts_controller.rb

    class AccountsController < ApplicationController
      def cancel
        current_account.subscription_cancel!
        redirect_to settings_account_path, :notice => "Your account has been canceled."
      end

      def reactivate
        current_account.subscription_reactivate!
        redirect_to settings_account_path, :notice => "Your account has been reactivated."
      end
    end



# app/views/accounts/form.html.erb

You need to provide the following fields in your form:

 * text_field_tag :credit_card_number, nil, :name => "" 
 * f.hidden_field :credit_card_token, :value => ""
 * f.date_select :credit_card_expires_on, :start_year => Date.today.year, :add_month_numbers => true, :order => [:month, :year]
 
It doesn't matter what resource these form fields are on, if they use the above names the following JS will find them.

    <script type="text/javascript" src="https://js.stripe.com/v1/"></script>
    <script type="text/javascript">
      Stripe.setPublishableKey('<%= STRIPE_PUBLISHABLE_KEY %>');

      $(document).ready(function() {
        $("form.user_edit").submit(function(event) {
          var form = $(this);
          form.find(".billing-errors").html("");
          if(form.find('#credit_card_number').val()) {
            form.find('[type=submit]').attr("disabled", "disabled");
            Stripe.createToken({
              number: form.find('[id*=credit_card_number]').val(),
              exp_month: form.find('[id*=credit_card_expires_on_2i]').val(),
              exp_year: form.find('[id*=credit_card_expires_on_1i]').val(),
              coupon: form.find('[name*=coupon]').val()
            }, function(status, response) {
              if (response.error) {
                form.find(".billing-errors").html(response.error.message);
                form.find('[type=submit]').removeAttr("disabled");
              } else {
                form.find("[name*=credit_card_token]").val(response['id']);
                form.get(0).submit();
              }
            });
            return false;
          }
        });
      });
    </script>
