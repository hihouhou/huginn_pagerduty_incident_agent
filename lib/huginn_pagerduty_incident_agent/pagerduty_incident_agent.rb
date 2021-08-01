module Agents
  class PagerdutyIncidentAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The PagerDuty incident Agent creates events with the PG api..

      `debug` is used for verbose mode.

      `email` is the email address of the user to record as having taken the action.

      `token` is the database's name.

       If `emit_events` is set to `true`, the server response will be emitted as an Event. No data processing
       will be attempted by this Agent, so the Event's "body" value will always be raw text.

      `data` is the payload (alert / system / foo / bar).

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "incident": {
            "incident_number": 3,
            "title": "test",
            "description": "test",
            "created_at": "2021-07-31T16:34:10Z",
            "status": "triggered",
            "incident_key": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "service": {
              "id": "XXXXXX",
              "type": "service_reference",
              "summary": "test",
              "self": "https://api.pagerduty.com/services/XXXXXX",
              "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/service-directory/XXXXXX"
            },
            "assignments": [
              {
                "at": "2021-07-31T16:34:11Z",
                "assignee": {
                  "id": "XXXXXX",
                  "type": "user_reference",
                  "summary": "XXXXXXXXXXXXXXX",
                  "self": "https://api.pagerduty.com/users/XXXXXX",
                  "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/users/XXXXXX"
                }
              }
            ],
            "assigned_via": "escalation_policy",
            "last_status_change_at": "2021-07-31T16:34:10Z",
            "first_trigger_log_entry": {
              "id": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
              "type": "trigger_log_entry_reference",
              "summary": "Triggered through the website",
              "self": "https://api.pagerduty.com/log_entries/XXXXXXXXXXXXXXXXXXXXXXXXXX",
              "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/incidents/XXXXXX/log_entries/XXXXXXXXXXXXXXXXXXXXXXXXXX"
            },
            "alert_counts": {
              "all": 0,
              "triggered": 0,
              "resolved": 0
            },
            "is_mergeable": true,
            "escalation_policy": {
              "id": "XXXXXX",
              "type": "escalation_policy_reference",
              "summary": "test-ep",
              "self": "https://api.pagerduty.com/escalation_policies/XXXXXX",
              "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/escalation_policies/XXXXXX"
            },
            "teams": [],
            "impacted_services": [
              {
                "id": "XXXXXX",
                "type": "service_reference",
                "summary": "test",
                "self": "https://api.pagerduty.com/services/XXXXXX",
                "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/service-directory/XXXXXX"
              }
            ],
            "pending_actions": [],
            "acknowledgements": [],
            "basic_alert_grouping": null,
            "alert_grouping": null,
            "last_status_change_by": {
              "id": "XXXXXX",
              "type": "service_reference",
              "summary": "test",
              "self": "https://api.pagerduty.com/services/XXXXXX",
              "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/service-directory/XXXXXX"
            },
            "incidents_responders": [],
            "responder_requests": [],
            "subscriber_requests": [],
            "urgency": "high",
            "id": "XXXXXX",
            "type": "incident",
            "summary": "[#3] test",
            "self": "https://api.pagerduty.com/incidents/XXXXXX",
            "html_url": "https://XXXXXXXXXXXXXX.pagerduty.com/incidents/XXXXXX"
          }
        }
    MD

    def default_options
      {
        'email' => '',
        'token' => '',
        'data' => '',
        'debug' => 'false',
        'emit_events' => 'false',
        'expected_receive_period_in_days' => '2',
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :emit_events, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :email, type: :string
    form_configurable :token, type: :string
    form_configurable :data, type: :string
    def validate_options
      unless options['email'].present?
        errors.add(:base, "email is a required field")
      end

      unless options['token'].present?
        errors.add(:base, "token is a required field")
      end

      unless options['data'].present?
        errors.add(:base, "data is a required field")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          trigger_event
        end
      end
    end

    def check
      trigger_event
    end

    private

    def trigger_event
  
      if interpolated['debug'] == 'true'
        log "data : #{interpolated['data']}"
      end

      uri = URI.parse("https://api.pagerduty.com/incidents")
      request = Net::HTTP::Post.new(uri)
      request.content_type = "application/json"
      request["From"] = "#{interpolated['email']}"
      request["Accept"] = "application/vnd.pagerduty+json;version=2"
      request["Authorization"] = "Token token=#{interpolated['token']}"
      request.body = interpolated['data']
#      request.body = JSON.dump({
#        "incident" => {
#          "type" => "incident",
#          "title" => "test",
#          "service" => {
#            "id" => "P0UCJLJ",
#            "type" => "service_reference"
#          }
#        }
#      })
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "request  status : #{response.code}"
  
      if interpolated['debug'] == 'true'
        log "response body : #{response.body}"
      end
  
      if interpolated['emit_events'] == 'true'
        create_event :payload => response.body 
      end
    end
  end
end
