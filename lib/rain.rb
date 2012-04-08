require "rain/version"

module Rain
  # Your code goes here...
  class Discretizer

    def initialize(instances, features, type="object")
      @discretized_instances = []
      @cut_points = {}
      @type = type
      @instances = instances
      @features = features

      @max_arity = @instances.length
      @max_cut_points = @max_arity - 1

      @columns = {}

      # get each feature's list of continuous-valued
      # attributes as an array
      @features.each do |f|
        @columns[f] = @instances.map{ |i| i.send(f) }
      end
    end

    def cut_points(feature=nil)
      if feature.nil?
        @cut_points
      else
        @cut_points[feature]
      end
    end

    def make_cutpoints_equalwidth(arity)
      # number of cut points = number of bins - 1
      num_cut_points = arity - 1

      @features.each do |f|
        # sort the continuous-valued attribute set
        attributes = @columns[f].sort()

        min = attributes.min()
        max = attributes.max()

        # find the continuouse-valued range
        range = max - min

        # divide the range by the number of bins
        width = range / arity

        #puts "Min:Max #{min}:#{max}, Range #{range} Bin Size: #{width}"

        # find cut points using the max of each bin
        cut_points = []
        (1..num_cut_points).each do |n|

          # the proposed cut point is the starting
          # value of the range plus n bin widths
          proposed_cut_point = min + (n * width)

          #puts "Min #{min}, Val #{x}, Width #{width}, Cut Point #{proposed_cut_point}"

          # the actual cut point will be the maximum
          # value found in the real data set that is
          # less than or equal to the proposed point
          actual_cut_point = attributes.select do |a|
            a <= proposed_cut_point
          end.max()

          cut_points << actual_cut_point
        end

        @cut_points[f] = cut_points
      end
    end
  end
end
