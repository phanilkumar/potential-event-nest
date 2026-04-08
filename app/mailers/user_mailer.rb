class UserMailer < ApplicationMailer
  def event_created(user, event)
    @user = user
    @event = event
    mail(to: user.email, subject: "Your event '#{event.title}' has been created")
  end

  def event_cancelled(user, event)
    @user = user
    @event = event
    mail(to: user.email, subject: "Event '#{event.title}' has been cancelled")
  end

  def order_confirmation(user, order)
    @user = user
    @order = order
    mail(to: user.email, subject: "Order #{order.confirmation_number} confirmed")
  end

  def order_cancelled(user, order)
    @user = user
    @order = order
    mail(to: user.email, subject: "Order #{order.confirmation_number} cancelled")
  end

  def order_confirmed(user, order)
    @user = user
    @order = order
    mail(to: user.email, subject: "Order #{order.confirmation_number} payment confirmed")
  end
end
