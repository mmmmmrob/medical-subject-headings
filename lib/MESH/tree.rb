module MESH

  class Tree

    @@default_locale = :en_us
    @@sw = Clarifier::StopWords.new()

    def initialize

      @headings_last_position = -1
      @headings = GoogleHashDenseLongToRuby.new
      @headings_by_unique_id = GoogleHashDenseLongToRuby.new
      @headings_by_tree_number = GoogleHashDenseLongToRuby.new
      @headings_by_original_heading = GoogleHashDenseLongToRuby.new
      @entries_by_term = GoogleHashDenseLongToRuby.new
      @entries_by_loose_match_term = GoogleHashDenseLongToRuby.new #case insensitive, no punctuation, normalised whitespace
      # @entries_by_word = Hash.new { |h, k| h[k] = Set.new }
      @entries_by_first_word = GoogleHashDenseLongToRuby.new
      # @entries_by_first_word = Hash.new { |h, k| h[k] = Set.new }
      @locales = [@@default_locale]

      filename = File.expand_path('../../../data/mesh_data_2014/d2014.bin.gz', __FILE__)
      gzipped_file = File.open(filename)
      file = Zlib::GzipReader.new(gzipped_file)

      lines = []
      file.each_line do |line|
        case
          when line.start_with?('*NEWRECORD')
            unless lines.empty?
              mh = MESH::Heading.new(self, @@default_locale, lines)
              @headings_last_position += 1
              @headings[@headings_last_position] = mh
              @headings_by_unique_id[mh.unique_id.hash] = mh
              @headings_by_original_heading[mh.original_heading.hash] = mh
              mh.tree_numbers.each do |tree_number|
                hash = tree_number.hash
                raise if @headings_by_tree_number[hash]
                @headings_by_tree_number[hash] = mh
              end
              mh.structured_entries.each do |entry|
                @entries_by_term[entry.term.hash] = entry
                @entries_by_loose_match_term[entry.loose_match_term.hash] = entry
                entry_words = entry.term.downcase.split(/\W+/)
                hash = entry_words[0].hash
                @entries_by_first_word[hash] ||= Set.new
                @entries_by_first_word[hash] << entry
              end
              lines = [line]
            end
          else
            lines << line
        end
      end

      (0..@headings_last_position).each do |i|
        # @headings.each do |heading|
        @headings[i].connect_to_parents
        @headings[i].connect_to_forward_references
      end

    end

    def load_translation(locale)
      return if @locales.include? locale
      filename = File.expand_path("../../../data/mesh_data_2014/d2014.#{locale}.bin.gz", __FILE__)
      gzipped_file = File.open(filename)
      file = Zlib::GzipReader.new(gzipped_file)

      unique_id = nil
      lines = []
      file.each_line do |line|

        case

          when line.start_with?('*NEWRECORD')
            unless unique_id.nil? || lines.empty?
              if heading = find_heading_by_unique_id(unique_id)
                new_entries = heading.load_translation(lines, locale)
                new_entries.each do |entry|
                  @entries_by_term[entry.term.hash] = entry
                  @entries_by_loose_match_term[entry.loose_match_term.hash] = entry
                  entry_words = entry.term.downcase.split(/\W+/)
                  hash = entry_words[0].hash
                  @entries_by_first_word[hash] ||= Set.new
                  @entries_by_first_word[hash] << entry
                end
              else
                raise 'Translation provided for missing header'
              end

              unique_id = nil
              lines = []
            end

          when matches = line.match(/^UI = (.*)/)
            unique_id = matches[1]

        end

        lines << line

      end
      @locales << locale
    end

    def load_wikipedia
      return if @wikipedia_loaded
      filename = File.expand_path("../../../data/mesh_data_2014/d2014.wikipedia.bin.gz", __FILE__)
      gzipped_file = File.open(filename)
      file = Zlib::GzipReader.new(gzipped_file)

      unique_id = nil
      wikipedia_links = []
      file.each_line do |line|

        case

          when line.match(/^\*NEWRECORD$/)
            unless unique_id.nil?
              if heading = find_heading_by_unique_id(unique_id)
                wikipedia_links.each do |wl|
                  wl[:score] = (wl[:score].to_f / heading.structured_entries.length.to_f).round(2)
                end
                heading.wikipedia_links = wikipedia_links
              end

              wikipedia_links = []
              unique_id = nil
            end

          when matches = line.match(/^UI = (.*)/)
            unique_id = matches[1]

          when matches = line.match(/^WK = (.*)/)
            hash = JSON.parse(matches[1], symbolize_names: true)
            wikipedia_links << hash

        end

      end
      @wikipedia_loaded = true
    end


    def linkify_summaries &block
      (0..@headings_last_position).each do |i|
        h = @headings[i]
      # @headings.each do |h|
        h.linkify_summary &block
      end
    end

    def find_heading_by_unique_id(unique_id)
      return @headings_by_unique_id[unique_id.hash]
    end

    def find_heading_by_tree_number(tree_number)
      return @headings_by_tree_number[tree_number.hash]
    end

    def find_heading_by_main_heading(heading)
      return @headings_by_original_heading[heading.hash]
    end

    def find_entry_by_term(term)
      return @entries_by_term[term.hash]
    end

    def find_entry_by_loose_match(term)
      return @entries_by_loose_match_term[Entry.loose_match(term).hash]
    end

    def find_entries_by_word(word)
      return @entries_by_first_word[word.hash]
    end

    def where(conditions)
      matches = []
      (0..@headings_last_position).each do |i|
      # @headings.each do |heading|
        heading = @headings[i]
        matches << heading if heading.matches(conditions)
      end
      matches
    end

    def each
      (0..@headings_last_position).each do |i|
        # for i in 0 ... @headings.size
        yield @headings[i] if @headings[i].useful
      end
    end

    def match_in_text (text)
      return [] if text.nil?
      downcased = text.downcase
      candidate_entries = []
      text_words = @@sw.clarify(downcased).split(/\W+/)
      text_words.uniq!
      text_words.each do |word|
        entries_by_word = find_entries_by_word(word)
        candidate_entries << entries_by_word.to_a
      end
      candidate_entries.compact!
      candidate_entries.flatten!
      # candidate_entries.uniq! #30% in this uniq
      candidate_entries.keep_if { |entry| entry.heading.useful }
      # puts "\n\n****\n#{candidate_entries.length}\n*****\n\n"
      matches = []
      candidate_entries.each do |entry|
        entry_matches = entry.match_in_text(text, downcased)
        matches << entry_matches
      end

      matches.compact!
      matches.flatten!

      matches.combination(2) do |l, r|
        if (r[:index][0] >= l[:index][0]) && (r[:index][1] <= l[:index][1])
          #r is within l
          r[:delete] = true
        elsif (l[:index][0] >= r[:index][0]) && (l[:index][1] <= r[:index][1])
          #l is within r
          l[:delete] = true
        end
      end
      matches.delete_if { |match| match[:delete] }
    end

    private


    def entry_match_key(e)
      e.strip.upcase
    end


  end

end