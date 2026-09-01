#
# require 'omniauth/cul'
#
# module Omniauth
#   module Cul
#     module ColumbiaCas
#       class << self
#         alias_method :original_validate, :validate
#
#         def validate(validation_url)
#           original_validate(validation_url).tap do |raw_response|
#             Rails.logger.info("=== RAW CAS VALIDATION RESPONSE ===\n#{raw_response}\n=== END RAW CAS VALIDATION RESPONSE ===")
#           end
#         end
#       end
#     end
#   end
# end
# 