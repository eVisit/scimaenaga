# frozen_string_literal: true

class ScimPatchOperationUser < ScimPatchOperation

  def save(model)
    case @op
    when 'add', 'replace'
      model.attributes = { @path_sp => @value }
    when 'remove'
      model.attributes = { @path_sp => nil }
    end
  end

  private

    def validate(_op, _path, value)
      if value.instance_of? Array
        raise Scimaenaga::ExceptionHandler::UnsupportedPatchRequest
      end

      return
    end

    def path_scim_to_path_sp(path_scim)
      # path_scim example1:
      # {
      #   attribute: 'emails',
      #   filter: {
      #     attribute: 'type',
      #     operator: 'eq',
      #     parameter: 'work'
      #   },
      #   rest_path: ['value']
      # }
      #
      # path_scim example2:
      # {
      #   attribute: 'name',
      #   filter: nil,
      #   rest_path: ['givenName']
      # }
      attribute = path_scim[:attribute].to_sym
      dig_keys = [attribute]

      if path_scim[:filter].present?
        array_index = get_array_index(attribute, path_scim[:filter])
        dig_keys << array_index if array_index.present?
      end

      dig_keys.concat(path_scim[:rest_path].map(&:to_sym))

      # *dig_keys example: emails, 0, value
      Scimaenaga.config.mutable_user_attributes_schema.dig(*dig_keys)
    end

    def get_array_index(attribute, filter)
      array = Scimaenaga.config.mutable_user_attributes_schema.dig(attribute)
      return nil unless array.present? || array.is_a?(Array)

      # Use only option if only one is present, also not sure what other operators exists so only supporting 'eq' for now.
      return 0 if array.count == 1 || filter[:operator] != 'eq'

      filter_attribute = filter[:attribute]&.to_sym
      index = array.find_index { |hash| hash[filter_attribute] == filter[:parameter] }
      index.nil? ? 0 : index
    end
end
