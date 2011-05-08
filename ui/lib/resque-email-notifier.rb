module Resque
  module Failure
    # Logs failure messages.
    class Logger < Base
      def save
        Rails.logger.error detailed
      end

      def detailed
        <<-EOF
#{worker} failed processing #{queue}:
Payload:
#{payload.inspect.split("\n").map { |l| " " + l }.join("\n")}
Exception:
#{exception}
#{exception.backtrace.map { |l| " " + l }.join("\n")}
EOF
      end
    end
    # Emails failure messages.
    class Notifier < Logger
      MSG_FROM = "error@somewhere.example.com"
      MSG_TO = "itcfg@example.com"
      def save
        text, subject = detailed, "[Error] #{queue}: #{exception}"
        mail = TMail::Mail.new
        mail.from = MSG_FROM
        mail.to = MSG_TO
        mail.subject = subject
        mail.body = text
        ActionMailer::Base.deliver(mail)
# FIXME: This is Rails 3.0 code
#        Mail.deliver do
#          from MSG_FROM
#          to MSG_TO
#          subject subject
#          text_part do
#            body text
#          end
#        end
      rescue Object => e
        puts "Failed to processs Notice: #{e.to_s}"
        puts e.backtrace
        puts $!
      end
    end

  end # Failure
end # Resque

