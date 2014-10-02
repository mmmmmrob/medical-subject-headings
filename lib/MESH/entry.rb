module MESH

  class Entry

    attr_accessor :heading, :term, :semantic_types, :semantic_relationship, :lexical_type, :regex, :case_sensitive, :downcased

    def initialize(heading, entry_text)
      @heading = heading
      @semantic_types = []
      parts = entry_text.split('|')
      if entry_text.include? '|'
        key = parts.pop
        parts.each_with_index do |part, i|
          case key[i]
            when 'a' # the term itself
              @term = part
            when 'b' # semantic type*
              @semantic_types << MESH::SemanticTypes[part]
            when 'c' # lexical type*
              @lexical_type = MESH::LexicalTypes[part]
            when 'd' # semantic relation*
              @semantic_relationship = MESH::SemanticRelationshipTypes[part]
            when 'e' # thesaurus id
            when 'f' # date
            when 's' # sort version
            when 'v' # entry version
          end
        end
      else
        @term = entry_text
        @downcased = entry_text.downcase
      end
      if /^[A-Z0-9]+$/ =~ @term
        @regex = /(^|\W)#{Regexp.quote(@term)}(\W|$)/
        @case_sensitive = true
      else
        @regex = /(^|\W)#{Regexp.quote(@term)}(\W|$)/i
        @case_sensitive = false
      end

    end

    def match_in_text(text)
      return nil if text.nil? || text.empty?
      if !@case_sensitive
        text = text.downcase
      end
      matches = []

      loose_match = @case_sensitive ? (text.include? @term) : (text.include? @downcased)
      if loose_match
        text.to_enum(:scan, @regex).map do |m,|
          match = Regexp.last_match
          matches << {heading: @heading, matched: self, index: match.offset(0)}
        end
      end

      matches.empty? ? nil : matches

    end

  end

end
