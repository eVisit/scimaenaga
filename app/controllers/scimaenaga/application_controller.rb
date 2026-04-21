# frozen_string_literal: true

module Scimaenaga
  class ApplicationController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ExceptionHandler
    include Response

    before_action :authorize_request
    around_action :notify_scim_action

    private

      def notify_scim_action
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        scim_error = nil
        resource_type = controller_name == 'scim_users' ? 'User' : 'Group'

        # Before callback: fires before the action, so any records it creates
        # are available to code that runs during the action (e.g., job enqueue callbacks).
        before_cb = Scimaenaga.config.on_scim_action_before
        if before_cb.respond_to?(:call)
          before_cb.call(
            company:        @company,
            resource_type:  resource_type,
            resource_id:    params[:id],
            action:         action_name,
            request_method: request.method,
            request_path:   request.path,
            request_body:   request.raw_post.truncate(5000)
          )
        end

        begin
          yield
        rescue => e
          scim_error = e
          raise
        ensure
          duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          status_code = scim_error ? status_code_for_exception(scim_error) : response.status

          # After callback: fires after the action completes (or fails).
          after_cb = Scimaenaga.config.on_scim_action_after
          if after_cb.respond_to?(:call)
            after_cb.call(
              status_code: status_code,
              success:     scim_error.nil?,
              error:       scim_error,
              duration_ms: duration
            )
          end

          # Legacy single callback (kept for backward compatibility)
          callback = Scimaenaga.config.on_scim_action
          if callback.respond_to?(:call)
            callback.call(
              company:        @company,
              resource_type:  resource_type,
              resource_id:    params[:id],
              action:         action_name,
              request_method: request.method,
              request_path:   request.path,
              request_body:   request.raw_post.truncate(5000),
              status_code:    status_code,
              success:        scim_error.nil?,
              error:          scim_error,
              duration_ms:    duration
            )
          end
        end
      end

      def status_code_for_exception(exception)
        case exception
        when Scimaenaga::ExceptionHandler::InvalidCredentials then 401
        when Scimaenaga::ExceptionHandler::InvalidRequest then 400
        when Scimaenaga::ExceptionHandler::InvalidQuery then 400
        when Scimaenaga::ExceptionHandler::UnsupportedPatchRequest then 422
        when Scimaenaga::ExceptionHandler::UnsupportedDeleteRequest then 501
        when Scimaenaga::ExceptionHandler::InvalidConfiguration then 500
        when Scimaenaga::ExceptionHandler::UnexpectedError then 500
        when Scimaenaga::ExceptionHandler::ResourceNotFound then 404
        when ActiveRecord::RecordNotFound then 404
        when Scimaenaga::ExceptionHandler::CustomScimError then exception.status_code
        when ActiveRecord::RecordInvalid
          exception.message.match?(/has already been taken/) ? 409 : 422
        else
          500
        end
      end

      def authorize_request
        send(authentication_strategy) do |searchable_attribute, authentication_attribute|
          authorization = AuthorizeApiRequest.new(
            searchable_attribute: searchable_attribute,
            authentication_attribute: authentication_attribute
          )
          @company = authorization.company
        end
        raise Scimaenaga::ExceptionHandler::InvalidCredentials if @company.blank?
      end

      def authentication_strategy
        if request.headers['Authorization']&.include?('Bearer')
          :authenticate_with_oauth_bearer
        else
          :authenticate_with_http_basic
        end
      end

      def authenticate_with_oauth_bearer
        authentication_attribute = request.headers['Authorization'].split.last
        payload = Scimaenaga::Encoder.decode(authentication_attribute).with_indifferent_access
        searchable_attribute = payload[Scimaenaga.config.basic_auth_model_searchable_attribute]

        yield searchable_attribute, authentication_attribute
      end

      def find_value_for(attribute)
        params.dig(*path_for(attribute))
      end

      # `path_for` is a recursive method used to find the "path" for
      # `.dig` to take when looking for a given attribute in the
      # params.
      #
      # Example: `path_for(:name)` should return an array that looks
      # like [:names, 0, :givenName]. `.dig` can then use that path
      # against the params to translate the :name attribute to "John".

      def path_for(attribute, object = controller_schema, path = [])
        at_path = path.empty? ? object : object.dig(*path)
        return path if at_path == attribute

        case at_path
        when Hash
          at_path.each do |key, _value|
            found_path = path_for(attribute, object, [*path, key])
            return found_path if found_path
          end
          nil
        when Array
          at_path.each_with_index do |_value, index|
            found_path = path_for(attribute, object, [*path, index])
            return found_path if found_path
          end
          nil
        end
      end
  end
end
