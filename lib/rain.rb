require "rain/version"

module Rain
  class Discretizer
    # Initialize {{{
    def initialize(instances, feature_names, type="equal-length")
      @type = type

      # the discretized  instances, i.e. the  instances that
      # have had their  continuous-valued features converted
      # to the appropriate bin numbers
      @results = []

      # bin boundaries for each feature
      @feature_cut_points = {}

      # each row of the data set
      @instances = instances

      # the list of  column names to discretize
      @feature_names = feature_names

      # the column ov values
      @feature_values = {}

      @known_classes = []

      # Get each feature's list of continuous-valued
      # attributes as an array. Accept both an array
      # of Hashes or an array of Objects such that
      # features may be provided as methods on an object
      # such as an ActiveRecord object
      if @instances.first.is_a?(Hash)
        @feature_names.each do |f|
          @feature_values[f] = @instances.map{ |i| i[f] }
        end
        @known_classes << @instances.map{ |i| i[:classification] }.uniq
      else
        @feature_names.each do |f|
          @feature_values[f] = @instances.map{ |i| i.send(f) }
        end
        @known_classes = @instances.map{ |i| i.classification }.uniq
      end
    end
    # }}}

    # Utilities {{{
    # Getters & Setters {{{
    def features
      @feature_values
    end

    def feature_names
      @feature_names
    end

    def feature(feature_name=nil)
      unless feature_name.nil?
        return @feature_values[feature_name]
      else
        []
      end
    end

    def feature_cut_points(feature_name=nil)
      if feature_name.nil?
        @feature_cut_points
      else
        @feature_cut_points[feature_name]
      end
    end
    # }}}

    # Fit Cutpoints to Population {{{
    def fit_feature_bins_to_population(cutpoints, values)
      new_cut_points = []

      # find cut points using the max of each bin
      cutpoints.each do |p|

        actual_cut_point = values.select{ |a| a <= p }.max()

        # the actual cut point will be the maximum
        # value found in the real data set that is
        # less than or equal to the proposed point
        actual_cut_point = values.select do |a|
          a <= p
        end.max()

        new_cut_points << actual_cut_point
      end

      new_cut_points
    end

    def fit_feature_bins_to_population!(feature_name)
      values = feature(feature_name)
      cutpoints = feature_cut_points(feature_name)

      results = fit_feature_bins_to_population(cutpoints, values)

      @feature_cut_points[feature_name] = results
    end

    def fit_bins_to_population
      results = {}
      @feature_names.each do |f|
        # get the list of known values for this feature
        values = feature(f)

        # get the computed cut points for this feature
        cutpoints = feature_cut_points(f)

        # fit the cutpoints of this feature to the actual
        # data in the data-set's population
        results[f] = fit_feature_bins_to_population(cutpoints, values)
      end

      results
    end

    def fit_bins_to_population!
      @feature_cut_points = fit_bins_to_population
    end
    # }}}

    # Helper Methods {{{
    def split_array(values, x)
      {
        :left  => values.slice(0,x),
        :right => values.slice(x..values.length-1)
      }
    end
    # }}}
    # }}}

    # Discretization Algorithms {{{
    # Equal Width {{{
    def make_feature_cutpoints_equalwidth(attributes, arity)
      # number of cut points = number of bins - 1
      num_cut_points = arity - 1

      # sort the continuous-valued attribute set
      attributes = attributes.sort()

      min = attributes.min()
      max = attributes.max()

      # find the continuouse-valued range
      range = max - min

      # divide the range by the number of bins
      width = range / arity

      #puts "Min:Max #{min}:#{max}, Range #{range} Bin Size: #{width}"

      # find cut points using the max of each bin
      cutpoints = []
      (1..num_cut_points).each do |n|

        # the proposed cut point is the starting
        # value of the range plus n bin widths
        proposed_cut_point = min + (n * width)

        cutpoints << proposed_cut_point
      end

      cutpoints
    end

    def make_cutpoints_equalwidth(arity)
      cutpoints = {}
      @feature_names.each do |f|
        # get the cut points for this feature
        feature = @feature_values[f]
        cuts = make_feature_cutpoints_equalwidth(feature, arity)

        # add this feature's cut points to the list
        cutpoints[f] = cuts
      end

      cutpoints
    end

    def make_cutpoints_equalwidth!(arity)
      results = make_cutpoints_equalwidth(arity)
      @feature_cut_points = results
    end

    def make_cutpoints_equalwidth_fit!(arity)
      make_cutpoints_equalwidth!(arity)
      fit_bins_to_population!
    end
    # }}}

    # Equal Length {{{
    def make_feature_cutpoints_equallength(attributes, arity)
      # number of cut points = number of bins - 1
      num_cut_points = arity - 1

      # sort the continuous-valued attribute set
      attributes = attributes.sort()

      # put an equal number of values in each bin
      count = attributes.length
      length = count.to_f / arity.to_f

      # find cut points using the max of each bin
      cutpoints = []
      (1..num_cut_points).each do |n|

        min = (n-1)*length
        max = n*length

        values = attributes.slice(min,length)
        next_values = attributes.slice(max,length)

        # the proposed cut point is the starting
        # value of the range plus the highest
        # value that occurs n bins from the start
        proposed_cut_point = values.max()

        # if the first value in the next bin is the
        # same as the last value in this bin, we'll
        # keep the cut point
        next_proposed_point = next_values.min()

        # if the next value is greater, we'll consider
        # that to be the cut_point
        if next_proposed_point > proposed_cut_point
          proposed_cut_point = next_proposed_point
        end

        cutpoints << proposed_cut_point
      end

      cutpoints
    end

    def make_cutpoints_equallength(arity)
      cutpoints = {}
      @feature_names.each do |f|
        # get the cut points for this feature
        feature = @feature_values[f]
        cuts = make_feature_cutpoints_equallength(feature, arity)

        # add this feature's cut points to the list
        cutpoints[f] = cuts
      end

      cutpoints
    end

    def make_cutpoints_equallength!(arity)
      results = make_cutpoints_equallength(arity)
      @feature_cut_points = results
    end

    def make_cutpoints_equallength_fit!(arity)
      make_cutpoints_equallength!(arity)
      fit_bins_to_population!
    end
    # }}}

    # Maximum Entropy {{{
    def make_cutpoints_mdlp(features)
      cutpoint_indexes = []

      puts "Current cutpoint indexes #{cutpoint_indexes.inspect}"

      # the features need to come through pre-sorted
      values  = features.map{|i|i[:value]}
      classes = features.map{|i|i[:classification]}

      #puts "Value Samples: #{values.inspect}"
      #puts "Class Samples: #{classes.inspect}"

      all_probs = []

      # store the class-entropy values of each cut point
      cutpoint_entropies = []

      # store the various stats about each cut point
      datums = []

      #class_probabilities[:all] = {}
      #class_probabilities[:left] = {}
      #class_probabilities[:right] = {}

      # get num total samples
      total_samples = @instances.length

      puts "Known classes: #{@known_classes.inspect}"

      puts "Sample length #{total_samples}"

      # get the probability of each class occuring
      # anywhere in the set
      @known_classes.each do |c|
        # get occurrences of this class within the total samples
        total_occur  = classes.count(c)
        puts "Total occurrences of #{c}: #{total_occur}"

        unless total_occur == 0
          probability = total_occur.to_f / total_samples.to_f

          puts "Probability of #{c}: #{probability}"

          # get num occurrences in left half
          all_probs << probability
        end
      end

      puts "All class probabilities: #{all_probs}"

      classes.length.times do |x|
        # create a split to the right of this item
        halves = split_array(classes, x)

        left_probs = []
        right_probs = []
        left_classes = 0
        right_classes = 0

        @known_classes.each do |c|
          # get num occurrences of this class on the left and right sides
          total_occur  = classes.count(c)
          left_occur   = halves[:left].count(c)
          right_occur  = halves[:right].count(c)

          unless left_occur == 0
            left_probs   << left_occur.to_f / total_occur.to_f
            left_classes  += 1
          end

          unless right_occur == 0
            right_probs  << right_occur.to_f / total_occur.to_f
            right_classes += 1
          end

          # not sure if we should include the class name(s) for
          # later reference like this
          #class_probabilities[:all][c]   = total_occurr / total_samples
          #class_probabilities[:left][c]  = left_occur / total_occurr
          #class_probabilities[:right][c] = right_occur / total_occurr
        end

        options = {
          all_probs: all_probs,
          left_probs: left_probs,
          right_probs: right_probs,
          left_classes: left_classes,
          right_classes: right_classes
        }

        #puts "Datum Options #{options.inspect}"

        datums << options

        # measure the class entropy of this cut point
        cutpoint_entropies << class_information_entropy(options)

        # not sure if we should save the index for later
        # this would only be useful when evaluating
        # multidimensional cut point values, i.e. a loop
        # within a loop to analyze, e.g. two cut points
        # at the same time
        #cutpoint_entropies << {index: x, entropy: class_information_entropy(options)}
      end

      #puts "Cutpoint entropies: #{cutpoint_entropies}"

      # select max class entropy as cut point
      max_entropy = cutpoint_entropies.max()

      puts "Max entropy: #{max_entropy}"

      x = cutpoint_entropies.find_index(max_entropy)

      puts "Cutpoint index: #{x}"

      options = datums[x]

      puts "Cutpoint Data: #{options}"

      #gain = gain_of_cutpoint(options).abs
      gain = gain_of_cutpoint(options)
      mdlp = mdlp_of_cutpoint(options)

      puts "Gain #{gain}"
      puts "MDLP #{mdlp}"

      # if we should make the cut based on the MDLP formula
      if gain > mdlp
        puts "Passes MDLP"

        # split at this cutpoint
        halves = split_array(features, x)

        puts "Left split: #{halves[:left].length}"
        puts "Right split: #{halves[:right].length}"

        #puts "Left split: #{halves[:left]}"
        #puts "Right split: #{halves[:right]}"

        s1 = halves[:left]
        s2 = halves[:right]

        # recurse on each side
        s1_cuts = make_cutpoints_mdlp(s1)
        puts "RETURN FROM LEFT RECURSION #{s1_cuts.inspect}"
        s2_cuts = make_cutpoints_mdlp(s2)
        puts "RETURN FROM RIGHT RECURSION #{s2_cuts.inspect}"
        puts "RETURN INDEX: #{x}"

        # append to array
        cutpoint_indexes = [x, s1_cuts, s2_cuts.map{|c|c+x}].flatten
      end

      puts "EOF index values: #{cutpoint_indexes}"
      cutpoint_indexes
    end

    def make_cutpoints_mdlp!(features)
      results = make_cutpoints_mdlp(features)
      puts "Cutpoint results: #{results}"
      @feature_cut_points = results
    end
    # }}}
    # }}}

    # Math Tools {{{
    def class_information_entropy(options={})
      s1 = options[:left_probs]
      s2 = options[:right_probs]

      n = options[:all_probs].length
      n1 = options[:left_probs].length
      n2 = options[:right_probs].length

      # class entropy formula
      (n1/n)*entropy(s1) + (n2/n)*entropy(s2)
    end

    def gain_of_cutpoint(options={})
      # Ent(S) - E(A, T; S)
      # entropy of the set - class information entropy of cutpoint
      s = options[:all_probs]
      entropy(s) - class_information_entropy(options)
    end

    def mdlp_of_cutpoint(options={})
      n = @instances.length # num samples

      k = @known_classes.length
      k1 = options[:left_classes] # num classes in s1
      k2 = options[:right_classes] # num classes in s2

      s  = options[:all_probs]
      s1 = options[:left_probs]
      s2 = options[:right_probs]

      # delta( A , T ; S )
      delta_ats = Math.log2(3**k-2) - k*entropy(s) - k1*entropy(s1) - k2*entropy(s2)

      (Math.log2(n-1)/n) + (delta_ats/n)
    end

    # set P = p(s0), p(s1), p(s2)
    # entropy H of set P = H(P) = Σi:n (p(si) * log(p(si))
    def entropy(probabilities)
      probabilities.inject(0) do |sum,p|
        sum += p * informational_value(p)
      end
    end

    def informational_value(probability)
      -Math.log2(probability)
    end

    def probability(needle, haystack)
      numNeedles = haystack.length - haystack.delete(needle).length
      numNeedls / haystack.length
    end
    # }}}
  end
end
