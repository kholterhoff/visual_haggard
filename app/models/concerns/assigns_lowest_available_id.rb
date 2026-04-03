module AssignsLowestAvailableId
  extend ActiveSupport::Concern

  included do
    before_create :assign_lowest_available_id, unless: :id?
    after_create :advance_primary_key_sequence_if_needed
  end

  class_methods do
    def lowest_available_id
      primary_key_column = connection.quote_column_name(primary_key)

      connection.select_value(<<~SQL.squish).to_i
        SELECT COALESCE(
          (SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM #{quoted_table_name} WHERE #{primary_key_column} = 1)),
          (
            SELECT MIN(existing_records.#{primary_key_column}) + 1
            FROM #{quoted_table_name} existing_records
            LEFT JOIN #{quoted_table_name} following_records
              ON following_records.#{primary_key_column} = existing_records.#{primary_key_column} + 1
            WHERE following_records.#{primary_key_column} IS NULL
          ),
          1
        )
      SQL
    end

    def lock_id_assignment!
      connection.execute("LOCK TABLE #{quoted_table_name} IN EXCLUSIVE MODE")
    end

    def primary_key_sequence_name
      connection.default_sequence_name(table_name, primary_key)
    rescue ActiveRecord::ActiveRecordError, NoMethodError, NotImplementedError
      connection.pk_and_sequence_for(table_name)&.last
    end

    def advance_primary_key_sequence_if_needed!
      sequence_name = primary_key_sequence_name
      return if sequence_name.blank?

      sequence_state = connection.select_one("SELECT last_value, is_called FROM #{connection.quote_table_name(sequence_name)}")
      return if sequence_state.blank?

      current_next_value = sequence_state["is_called"] ? sequence_state["last_value"].to_i + 1 : sequence_state["last_value"].to_i
      maximum_assigned_id = unscoped.maximum(primary_key).to_i
      return if current_next_value > maximum_assigned_id

      connection.execute("SELECT setval(#{connection.quote(sequence_name)}, #{maximum_assigned_id}, true)")
    rescue ActiveRecord::ActiveRecordError
      nil
    end
  end

  private

  def assign_lowest_available_id
    self.class.lock_id_assignment!
    self.id = self.class.lowest_available_id
  end

  def advance_primary_key_sequence_if_needed
    self.class.advance_primary_key_sequence_if_needed!
  end
end
