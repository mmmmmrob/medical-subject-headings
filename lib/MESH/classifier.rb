module MESH
  class Classifier
    def classify(weighted_matches)

      weighted_headings = []
      weighted_matches.each do |wm|
        wm[:matches].each do |match|
          weighted_headings << [wm[:weight], match[:heading]]
        end
      end

      root_groups = {}
      weighted_headings.each do |weight, heading|
        heading.roots.each do |root|
          root_groups[root] ||= []
          root_groups[root] << [weight, heading]
        end
      end

      chosen = {}

      root_groups.each do |root, weighted_headings|
        scored = {}
        weighted_headings.each do |weight, heading|
          calculate_scores(scored, root, heading, weight)
          #scored[heading] ||= 0
          #scored[heading] += weight
          #heading.parents.each do |p|
          #  if p.roots.include? root
          #    scored[p] ||= 0
          #    scored[p] += weight / 3.0
          #  end
          #end
        end
        scored.each { |h,s| scored[h] = s.round(3) }
        scored.delete_if { |h,s| s == 0 }
        best_score, best_connected = scored.reduce({}) { |h, (k, v)| (h[v] ||= []) << k; h }.max
        most_specific = best_connected.max_by { |h| h.deepest_position(root) }
        #chosen[root] = [most_specific, best_score]
        chosen[root] = [best_score, scored]
      end

      chosen

    end

    def calculate_scores(scored, root, heading, weight)
      scored[heading] ||= 0
      scored[heading] += weight
      heading.parents.each do |p|
        if p.roots.include? root
          calculate_scores(scored, root, p, weight / 3.0)
        end
      end
    end




    #text = "#{document[:title]}\n#{document[:abstract]}\n#{document[:content]}"
    #matches = MESH::Mesh.match_in_text(text)
    #headings = matches.map { |m| m[:heading] }
    #root_groups = headings.reduce({}) do |rg, heading|
    #  heading.roots.each { |root| (rg[root] ||= []) << heading }
    #  rg
    #end
    #root_groups.reduce({}) do |chosen, (root, candidates)|
    #  connections = calculate_connections(root, candidates)
    #  best_score, best_connected = connections.reduce({}) { |h, (k, v)| (h[v] ||= []) << k; h }.max
    #  most_specific = best_connected.max_by { |h| h.deepest_position }
    #  chosen[root] = most_specific
    #  chosen
    #end
    #end

    private

    def calculate_connections(root, headings, weight)
      connections = {}
      headings.each do |h|
        add_connection(connections, root, h, weight)
      end
      connections
    end

    def add_connection(connections, root, heading, weight)
      return unless heading.roots.include? root
      connections[heading] ||= 0
      connections[heading] += weight
      heading.parents.each do |p|
        connections[p] ||= 0
        connections[p] += weight
        #add_connection(connections, root, p, weight)
      end
      #heading.siblings.each do |p|
      #  add_connection(connections, p)
      #end
    end

  end

end

