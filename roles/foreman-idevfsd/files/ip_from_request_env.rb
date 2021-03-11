# coding: utf-8
#
# Cut out the bravo-sierra^W^W“reasoning explained at length” quoted
# in https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html
# (in which you basically get lectured on why you cannot possibly want
# to use Rails in intranet applications):
module Foreman
  module Controller
    module IpFromRequestEnv
      extend ActiveSupport::Concern

      protected

      def ip_from_request_env
        # Trust Træfik - we put it there for a reason
        request.x_forwarded_for
      end
    end
  end
end
