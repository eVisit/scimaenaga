# frozen_string_literal: true

# Parse PATCH request
class ScimPatch
  attr_accessor :operations

  def initialize(params, resource_type)
    if params['schemas'] != ['urn:ietf:params:scim:api:messages:2.0:PatchOp'] ||
       params['Operations'].nil?
      raise Scimaenaga::ExceptionHandler::UnsupportedPatchRequest
    end

    # complex-value(Hash) operation is converted to multiple single-value operations
    converted_operations = ScimPatchOperationConverter.convert(params['Operations'])
    @operations = converted_operations.map do |o|
      create_operation(resource_type, o['op'], o['path'], o['value'])
    end
  end

  def create_operation(resource_type, op, path, value)
    if resource_type == :user
      operation = ScimPatchOperationUser.new(op, path, value)
      Scimaenaga.config.user_association_schemas.each do |key, schema|
        next unless schema.keys.include?(operation.path_sp)

        operation.association = key
      end

      operation
    else
      ScimPatchOperationGroup.new(op, path, value)
    end
  end

  def save(model)
    model.transaction do
      @operations.each do |operation|
        next if operation.path_sp.blank? || operation.association.present?

        operation.save(model)
      end
      model.save! if model.changed?
    end
  rescue ActiveRecord::RecordNotFound
    raise
  rescue StandardError => e
    raise Scimaenaga::ExceptionHandler::UnsupportedPatchRequest, e.message
  end
end
