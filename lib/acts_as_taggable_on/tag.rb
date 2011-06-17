module ActsAsTaggableOn
  class Tag < ::ActiveRecord::Base
    include ActsAsTaggableOn::ActiveRecord::Backports if ::ActiveRecord::VERSION::MAJOR < 3
  
    attr_accessible :name
    
    translates :name
    
    before_create :set_token
    
    ### ASSOCIATIONS:

    has_many :taggings, :dependent => :destroy, :class_name => 'ActsAsTaggableOn::Tagging'

    ### VALIDATIONS:

    #validates_presence_of :token
    #validates_uniqueness_of :token

    ### SCOPES:
    
    def self.using_postgresql?
      connection.adapter_name == 'PostgreSQL'
    end

    def self.named(name)
      where(["#{self.translations_table_name}.name #{like_operator} ?", name]).includes(:translations)
    end
  
    def self.named_any(list)
      includes(:translations).where(list.map { |tag| sanitize_sql(["#{self.translations_table_name}.name #{like_operator} ?", tag.to_s]) }.join(" OR "))
    end
  
    def self.named_like(name)
      where(["#{self.translations_table_name}.name #{like_operator} ?", "%#{name}%"]).includes(:translations)
    end

    def self.named_like_any(list)
      includes(:translations).where(list.map { |tag| sanitize_sql(["#{self.translations_table_name}.name #{like_operator} ?", "%#{tag.to_s}%"]) }.join(" OR "))
    end

    ### CLASS METHODS:

    def self.find_or_create_with_like_by_name(name)
      raise named_like(name).inspect
      named_like(name).first || create(:name => name)
    end

    def self.find_or_create_all_with_like_by_name(*list)
      list = [list].flatten

      return [] if list.empty?
      
      existing_tags = Tag.named_any(list).all
      
      #raise existing_tags.collect{|t| comparable_name(t.name)}.inspect + list.collect{|n| comparable_name(n)}.inspect unless existing_tags.empty?
      
      new_tag_names = list.reject do |name| 
                        existing_tags.any? { |tag| comparable_name(tag.name) == comparable_name(name) }
                      end
      created_tags  = new_tag_names.map { |name| Tag.create(:name => name) }

      existing_tags + created_tags
    end

    ### INSTANCE METHODS:

    def ==(object)
      super || (object.is_a?(Tag) && name == object.name)
    end

    def to_s
      name
    end

    def count
      read_attribute(:count).to_i
    end
    
    def set_token
      token = ""#name.downcase if (token.nil? || token.empty?) && !name.nil?
    end

    class << self
      private
        def like_operator
          using_postgresql? ? 'ILIKE' : 'LIKE'
        end
        
        def comparable_name(str)
          RUBY_VERSION >= "1.9" ? str.downcase : str.mb_chars.downcase
        end
    end
  end
end