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
      attribute = path_scim[:attribute]

      # Handle SCIM extension URI paths (RFC 7644 Section 3.10)
      # e.g., "urn:ietf:params:scim:schemas:extension:evisit:2.0:User:npi"
      # parse_path_scim splits on '.' so the full colon-delimited URI+attribute
      # arrives as a single attribute string; rest_path has any dot-separated
      # sub-attributes that followed.
      if attribute.start_with?('urn:')
        return resolve_extension_path(attribute, path_scim[:rest_path])
      end

      attribute_sym = attribute.to_sym
      dig_keys = [attribute_sym]

      if path_scim[:filter].present?
        array_index = get_array_index(attribute_sym, path_scim[:filter])
        dig_keys << array_index if array_index.present?
      end

      dig_keys.concat(path_scim[:rest_path].map(&:to_sym))

      # *dig_keys example: emails, 0, value
      Scimaenaga.config.mutable_user_attributes_schema.dig(*dig_keys)
    end

    # Resolves a SCIM extension URI path to the corresponding model attribute
    # by matching against String keys in mutable_user_attributes_schema.
    #
    # Extension paths use colon separators:
    #   urn:ietf:params:scim:schemas:extension:evisit:2.0:User:npi
    # The schema stores the URI portion as a String key:
    #   "urn:ietf:params:scim:schemas:extension:evisit:2.0:User" => { npi: :npi, ... }
    def resolve_extension_path(attribute_str, rest_path)
      schema = Scimaenaga.config.mutable_user_attributes_schema

      schema.each do |key, value|
        next unless key.is_a?(String) && attribute_str.start_with?(key)
        # Ensure match is at a URI boundary (exact match or followed by ':')
        next unless attribute_str.length == key.length || attribute_str[key.length] == ':'

        remainder = attribute_str.delete_prefix(key).delete_prefix(':')
        dig_keys = []
        dig_keys << remainder.to_sym if remainder.present?
        dig_keys.concat(rest_path.map(&:to_sym)) if rest_path.present?

        return value if dig_keys.empty?
        return value.dig(*dig_keys) if value.is_a?(Hash)
      end

      nil
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
