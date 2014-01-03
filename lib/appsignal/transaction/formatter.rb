require 'delegate'

module Appsignal
  class Transaction
    class Formatter < SimpleDelegator
      def hash
        @hash ||= default_hash
      end

      def to_hash
        merge_process_action_event_with_log_entry! if process_action_event
        add_queue_duration_to_hash!
        if exception?
          add_exception_to_hash!
          add_tags_to_hash!
        end
        add_events_to_hash! if slow_request?
        hash
      end

      protected

      def default_hash
        {
          :request_id => request_id,
          :log_entry => {
            :path => fullpath,
            :kind => kind,
            :time => time,
            :environment => sanitized_environment,
            :session_data => sanitized_session_data
          },
          :failed => exception?
        }
      end

      def merge_process_action_event_with_log_entry!
        hash[:log_entry].merge!(event_to_hash(process_action_event))
        hash[:log_entry].tap do |o|
          o.merge!(o.delete(:payload))
          o.delete(:controller)
          o.delete(:action)
          o.delete(:name)
          o.delete(:class)
          o.delete(:method)
          o.delete(:queue_start)
          o[:action] = action
        end
      end

      def add_queue_duration_to_hash!
        start = queue_start || 0.0
        if start > 0
          hash[:log_entry][:queue_duration] = hash[:log_entry][:time] - start
        end
      end

      def add_tags_to_hash!
        hash[:log_entry][:tags] = tags
      end

      def add_exception_to_hash!
        hash[:exception] = {
          :exception => exception.class.name,
          :message => exception.message,
          :backtrace => clean_backtrace(exception)
        }
      end

      def clean_backtrace(exception)
        if defined?(::Rails)
          ::Rails.backtrace_cleaner.clean(exception.backtrace, nil)
        else
          exception.backtrace
        end
      end

      def add_events_to_hash!
        hash[:events] = events.map do |event|
          event_to_hash(event)
        end
      end

      def event_to_hash(event)
        {
          :name => event.name,
          :duration => event.duration,
          :time => event.time.to_f,
          :end => event.end.to_f,
          :payload => event.payload
        }
      end
    end
  end
end
