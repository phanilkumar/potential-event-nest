class ApplicationMailer < ActionMailer::Base
  default from: "notifications@eventnest.dev"
  layout "mailer"
end
