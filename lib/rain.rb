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

      # Get each feature's list of continuous-valued
      # attributes as an array. Accept both an array
      # of Hashes or an array of Objects such that
      # features may be provided as methods on an object
      # such as an ActiveRecord object
      if @instances.first.is_a?(Hash)
        @feature_names.each do |f|
          @feature_values[f] = @instances.map{ |i| i[f] }
        end
      else
        @feature_names.each do |f|
          @feature_values[f] = @instances.map{ |i| i.send(f) }
        end
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
    # }}}
  end
end
