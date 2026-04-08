class CrmSyncJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order

    Rails.logger.info("Syncing order #{order_id} to CRM")
  end
end
