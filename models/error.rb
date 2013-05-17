class Error < Sequel::Model
  many_to_one :application

  dataset_module do
    def search(term)
      full_text_search(:search_text, term)
    end
    def most_recent(limit)
      reverse_order(:created_at).limit(limit)
    end
  end
end
