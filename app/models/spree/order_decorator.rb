module SpreeAvataxOfficial
  module Spree
    module OrderDecorator
      def self.prepended(base)
        base.register_update_hook :recalculate_avatax_taxes

        base.has_many :avatax_transactions, class_name: 'SpreeAvataxOfficial::Transaction'

        base.has_one :avatax_sales_order_transaction, -> { where(transaction_type: 'SalesOrder') },
                     class_name: 'SpreeAvataxOfficial::Transaction',
                     inverse_of: :order

        base.has_one :avatax_sales_invoice_transaction, -> { where(transaction_type: 'SalesInvoice') },
                     class_name: 'SpreeAvataxOfficial::Transaction',
                     inverse_of: :order

        base.state_machine.after_transition to: :canceled, do: :void_in_avatax
      end

      def all_items
        line_items + shipments
      end

      def avatax_sales_invoice_code
        avatax_sales_invoice_transaction&.code
      end

      def avatax_tax_calculation_required?
        tax_address.present? && line_items.any?
      end

      def create_tax_charge!
        return super unless SpreeAvataxOfficial::Config.enabled

        SpreeAvataxOfficial::CreateTaxAdjustments.call(order: self)
      end

      def recalculate_avatax_taxes
        return unless SpreeAvataxOfficial::Config.enabled

        SpreeAvataxOfficial::CreateTaxAdjustments.call(order: self)
        update_totals
      end

      private

      def void_in_avatax
        return unless SpreeAvataxOfficial::Config.enabled

        SpreeAvataxOfficial::Transactions::VoidService.call(order: self)
      end
    end
  end
end

Spree::Order.prepend ::SpreeAvataxOfficial::Spree::OrderDecorator