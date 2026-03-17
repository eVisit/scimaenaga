# frozen_string_literal: true

module Scimaenaga
  module Response
    CONTENT_TYPE = 'application/scim+json'

    def json_response(object, status = :ok)
      render \
        json: object,
        status: status,
        content_type: CONTENT_TYPE
    end

    def json_scim_response(object:, status: :ok, counts: nil)
      case params[:action]
      when 'index'
        render \
          json: list_response(object, counts),
          status: status,
          content_type: CONTENT_TYPE
      when 'show', 'create', 'put_update', 'patch_update'
        render \
          json: object_response(object),
          status: status,
          content_type: CONTENT_TYPE
      end
    end

    private

      def list_response(object, counts)
        object = object
                 .order(:id)
                 .offset(counts.offset)
                 .limit(counts.limit)
        {
          schemas: [
            'urn:ietf:params:scim:api:messages:2.0:ListResponse'
          ],
          totalResults: counts.total,
          startIndex: counts.start_index,
          itemsPerPage: counts.limit,
          Resources: list_objects(object),
        }
      end

      def list_objects(objects)
        objects.map do |object|
          object_response(object)
        end
      end

      def object_response(object)
        schema = case object
                 when Scimaenaga.config.scim_users_model
                   Scimaenaga.config.user_schema
                 when Scimaenaga.config.scim_groups_model
                   Scimaenaga.config.group_schema
                 else
                   raise Scimaenaga::ExceptionHandler::InvalidQuery,
                         "Unknown model: #{object}"
                 end
        find_value(object, schema)
      end

      # `find_value` is a recursive method that takes a "user" and a
      # "user schema" and replaces any symbols in the schema with the
      # corresponding value from the user. Given a schema with symbols,
      # `find_value` will search through the object for the symbols,
      # send those symbols to the model, and replace the symbol with
      # the return value.

      def find_value(object, schema)
        case schema
        when Hash
          if schema.count == 1 && Scimaenaga.config.user_association_schemas.keys.include?(schema.keys.first)
            find_value(object.public_send(schema.keys.first), schema.values.first)
          else
            schema.each.with_object({}) do |(key, value), hash|
              hash[key] = find_value(object, value)
            end
          end
        when ActiveRecord::Associations::CollectionProxy
          select_abbreviated_columns(schema).map do |value|
            find_value(object, value)
          end
        when Array
          schema.map do |value|
            find_value(object, value)
          end
        when Scimaenaga.config.scim_users_model
          find_value(schema, Scimaenaga.config.user_abbreviated_schema)
        when Scimaenaga.config.scim_groups_model
          find_value(schema, Scimaenaga.config.group_abbreviated_schema)
        when Symbol
          object.blank? ? nil : find_value(object, object.public_send(schema))
        else
          schema
        end
      end

      # When serializing a collection of users/groups for the SCIM response,
      # select only the columns referenced by the abbreviated schema instead
      # of loading every column. This avoids SELECT * on wide tables like
      # users when only :id and :email are needed.
      def select_abbreviated_columns(collection)
        abbreviated_schema = if collection.klass == Scimaenaga.config.scim_users_model
                               Scimaenaga.config.user_abbreviated_schema
                             elsif collection.klass == Scimaenaga.config.scim_groups_model
                               Scimaenaga.config.group_abbreviated_schema
                             end

        return collection unless abbreviated_schema

        columns = abbreviated_schema.values.select { |v| v.is_a?(Symbol) }
        column_names = collection.klass.column_names

        # Only optimize when every needed value is a direct DB column.
        # If any value is a model method, fall back to loading all columns
        # so the method has access to whatever attributes it needs.
        if columns.present? && columns.all? { |c| column_names.include?(c.to_s) }
          collection.select(*columns)
        else
          collection
        end
      end
  end
end
