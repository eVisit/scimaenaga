# frozen_string_literal: true

module Scimaenaga
  class ScimQueryParser
    attr_accessor :query_elements, :query_attributes

    def initialize(query_string, queryable_attributes)
      self.query_elements = query_string.gsub(/\[(.+?)\]/, '.0').split
      self.query_attributes = queryable_attributes
    end

    def attribute
      attribute = query_elements[0]
      raise Scimaenaga::ExceptionHandler::InvalidQuery if attribute.blank?

      dig_keys = attribute.split('.').map do |step|
        step == '0' ? 0 : step.to_sym
      end

      mapped_attribute = query_attributes.dig(*dig_keys)
      raise Scimaenaga::ExceptionHandler::InvalidQuery if mapped_attribute.blank?

      mapped_attribute
    end

    def operator
      sql_comparison_operator(query_elements[1])
    end

    def parameter
      parameter = query_elements[2..-1].join(' ')
      return if parameter.blank?

      parameter.gsub!(/"/, '')

      if operator == 'LIKE'
        case query_elements[1]
        when 'co'
          "%#{parameter}%"
        when 'sw'
          "#{parameter}%"
        when 'ew'
          "%#{parameter}"
        else
          parameter
        end
      else
        case parameter.downcase
        when 'true'
          true
        when 'false'
          false
        else
          parameter
        end
      end
    end

    private

      def sql_comparison_operator(element)
        case element
        when 'eq'
          '='
        when 'ne'
          '!='
        when 'co', 'sw', 'ew'
          'LIKE'
        when 'gt'
          '>'
        when 'ge'
          '>='
        when 'lt'
          '<'
        when 'le'
          '<='
        else
          # TODO: implement additional query filters
          raise Scimaenaga::ExceptionHandler::InvalidQuery
        end
      end
  end
end
