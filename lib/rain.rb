require "rain/version"

module Rain
  module GA
    # Encoder {{{
    class Encoder
      attr_reader :encoding, :decoding, :values, :num_bits

      def initialize(values=nil, num_bits=nil)
        # by default, keep everything about the same size
        @values     = values
        @num_values = values.length
        @num_bits   = Math.log2(@num_values).ceil
        build_encoding_key
      end

      def build_encoding_key
        unless @values.nil?
          @num_bits ||= Math.log2(@values.length).ceil

          @decoding = Hash[@values.each_with_index.map { |val,i|
            [i.to_s(2).rjust(@num_bits,'0'), val]
          }]

          @encoding = Hash[@values.each_with_index.map { |val,i|
            [val, i.to_s(2).rjust(@num_bits,'0')]
          }]

          @bitstrings = @decoding.keys
        end
      end

      def randval
        rand_value
      end

      def randbs
        rand_bitstring
      end

      def rand_value
        @values[rand(0..@num_values-1)]
      end

      def rand_bitstring
        @bitstrings[rand(0..@num_values-1)]
      end

      def encode(value)
        #puts "encoding #{value} as #{@encoding[value]}"
        @encoding[value]
      end

      def decode(value)
        #puts "decoding #{value} as #{@decoding[value]}"
        @decoding[value]
      end

      def length
        #puts "length is #{@num_bits}"
        @num_bits
      end
    end
    # }}}

    # Gene {{{
    class Gene
      attr_reader :encoder

      def initialize(encoder=nil, val=nil, encoded=true)
        raise "Gene requires encoder to be present" if encoder.nil?

        @encoder = encoder

        # if no value is provided then
        # initialize a random value
        if val.nil?
          @bitstring = @encoder.randbs
        else
          if encoded
            @bitstring = val
          else
            @bitstring = @encoder.encode(val)
          end
        end
      end

      def value=(val)
        @bitstring = @encoder.encode(val)
      end

      # set the value for this gene
      def bitstring=(bitstring)
        @bitstring = val
      end

      def valid?
        # if it has a value, and the value is
        # known by the encoder
        !encoded.nil? && !decoded.nil?
      end

      # the value of this gene is stored
      # in decoded form already
      def decoded
        @encoder.decode(encoded)
      end

      # helper function that passes
      # through to encoder object
      # to decode the value
      def encoded
        @bitstring.rjust(length, "0")
      end

      def randomize!
        @bitstring = @encoder.randbs
      end

      def length
        @encoder.length
      end
    end
    # }}}

    # Genome {{{
    class Genome
      attr_accessor :encoders, :genes, :use_reals

      def initialize(genes=[])
        @use_reals = false
        @genes = genes
      end

      def genes_use_real_numbers?
        @use_reals
      end

      def value=(vals)
        new_genes = []

        # split the new bitstring up by gene
        @genes.each_with_index do |g,x|
          # create a new gene using the old
          # encoder but using the new value
          n = Gene.new(g.encoder)
          n.value = vals[x]

          new_genes << n
        end

        @genes = new_genes
      end

      def bitstring=(bitstring)
        new_genes = []

        # split the new bitstring up by gene
        @genes.each do |g|
          # split off one gene worth of bits
          encoded_gene, bitstring = split_array(bitstring, g.length)

          # create a new gene using the old encoder
          # but using the new bitstring
          new_genes << Gene.new(g.encoder, encoded_gene)
        end

        @genes = new_genes
      end

      def valid?
        # none of the genes are invalid, 
        # i.e. all of the genes are valid
        !@genes.map(&:valid?).uniq.include?(false)
      end

      def encoded
        @genes.map(&:encoded).join.rjust(@genes.map(&:length).reduce(:+), "0")
      end

      def decoded
        @genes.map(&:decoded).join
      end

      def randomize!
        @genes.each do |g|
          g.randomize!
        end
      end

      def split(split_point)
        split_array(encoded, split_point)
      end

      def encoders
        @genes.map(&:encoder)
      end

    private
      def split_array(array, split_point)
        [ array.slice(0,split_point), array.slice(split_point..array.length-1) ]
      end
    end
    # }}}

    # Chromosome {{{
    class Chromosome
      attr_accessor :age, :fitness, :probability, :mutation_rate

      def initialize(options={}, bs=nil)
        gs =
          if options[:gene_sequence]
            options[:gene_sequence]
          else
            []
          end

        @gene_sequence = gs.map do |e|
          Gene.new(e)
        end

        @genome = Genome.new(@gene_sequence)

        @age = 0
        @mutation_rate = options[:mutation_rate]
        @mask_entire_features = options[:mask_entire_features]
        @force_mask_percentage = options[:force_mask_percentage]
        @mask_percentage = options[:mask_percentage] || 0.33

        @genome.bitstring = bs unless bs.nil?
      end

      def to_s
        "#{encoded}\t#{decoded}\t$: #{fitness.to_s.ljust(17, '0')}\t%: #{probability}"
      end

      def value=(val)
        @genome.value = val
      end

      def bitstring=(val)
        @genome.bitstring = val
      end

      def encoded
        @genome.encoded
      end

      def decoded
        @genome.decoded
      end

      def to_s
        "#{encoded}\t#{decoded}"
      end

      def valid?
        @genome.valid?
      end

      def randomize!
        @genome.randomize!
      end

      def mask
        unless @mask
          if @force_mask_percentage
            #puts "forced mask percentage"
            if @mask_entire_features
              #puts "mask entire features"
              @num_masked_genes = (@genome.decoded.length.to_f * @mask_percentage.to_f).ceil
              #puts "mask percentage #{@mask_percentage}"
              #puts "num masked genes #{@num_masked_genes}"
              #puts "genome length #{@genome.decoded.length}"

              masked_indexes = []

              # mask the appropriate number of genes
              (1..@num_masked_genes).each do |x|
                # roll a die to choose a gene to randomly
                # mask, if that gene has already been masked
                # then roll again so we have the full required
                # amount of masked genes
                begin
                  roll = rand(0..@genome.decoded.length-1)
                  #puts "Random roll #{roll}"
                end while masked_indexes.include?(roll)

                masked_indexes << roll
              end

              #puts "masked indexes #{masked_indexes}"

              # grab the encoder off of each gene
              result = ""
              @genome.encoders.each_with_index do |e,i|
                #puts "gene ##{i}"
                if masked_indexes.include?(i)
                  #puts "masked"
                  bit = "1"
                else
                  #puts "not masked"
                  bit = "0"
                end

                # take the chosen bit for the mask on this
                # gene and repeat it as many times as
                # there are bits in this gene to mask
                # out the entire gene
                result += bit * e.length
              end
            else
            end
          else
            if @mask_entire_features
            else
              result = (1..@genome.encoded.length).map do |x|
                roll = rand

                # %33 chance that this bit doesn't matter
                if roll >= 0 and roll < @mask_percentage
                  c = "1"
                else
                  c = "0"
                end
              end.join
            end
          end

          #puts "result mask #{result}"
          @mask = result
        end

        @mask.rjust(@genome.encoded.length, "0")
      end

      def mask=(val)
        @mask = val
      end

      def masked(m=nil)
        m ||= mask
        result = (@genome.encoded.to_i(2) | m.to_i(2)).to_s(2)
        result.to_s.rjust(@genome.encoded.length, "0")
      end

      def mutate!
        # TODO: make this work
        #if @use_real_genes
        #  @genes.each do |g|
        #    g.value += (rand - rand) * @mutation_clamper
        #  end
        #else
          old_bitstring = @genome.encoded
          mutated_bitstring = ""

          num_mutations = 0
          bit_counter = 0
          mutated_indexes = []
          old_bitstring.each_char do |c|
            new_bit = c

            # optionally perform mutation
            die_roll = rand
            if die_roll <= @mutation_rate
              num_mutations += 1
              mutated_indexes << bit_counter

              # flip the bit
              if c == "1"
                new_bit = "0"
              else
                new_bit = "1"
              end

              #puts "Old Value #{c}, New Value #{new_bit}"
            end

            mutated_bitstring += new_bit
            bit_counter += 1
          end

          bitstring = mutated_bitstring
        #end
      end

      def split(split_point)
        @genome.split(split_point)
      end

      def fitness
        @fitness ||= rand
      end

      def length
        @genome.genes.map(&:length).reduce(:+)
      end
    end
    # }}}

    # Pool {{{
    class Pool
      attr_reader :chromosomes, :old_fitness, :new_fitness, :solutions, :total_solutions

      def initialize(options={})
        @chromosomes = []

        @generation = 0
        @chromosome_class =
          if options[:chromosome_class]
            options[:chromosome_class]
          else
            Chromosome
          end

        set_options(options)
      end

      def set_options(options={})
        @crossover_rate  = options[:crossover_rate]       unless options[:crossover_rate].nil?
        @population_size = options[:population_size]      unless options[:population_size].nil?
        @num_generations = options[:num_generations]      unless options[:num_generations].nil?

        @chromosome_settings = {
          :gene_sequence => options[:gene_sequence],
          :mutation_rate => options[:mutation_rate],
          :force_mask_percentage => options[:force_mask_percentage],
          :mask_percentage => options[:mask_percentage],
          :mask_entire_features => options[:mask_entire_features]
        }
      end

      def randomize!
        while @chromosomes.length < @population_size
          c = @chromosome_class.new(@chromosome_settings)

          # generate a random gene sequence
          begin
            c.randomize!
          end until valid?(c)

          @chromosomes.push(c)
        end

        #@chromosomes.each do |c|
        #  puts c
        #end
        #puts "random chromosomes"
      end

      def evolve!
        #puts "Evolving"

        # pre-sort the population by fitness
        # i.e. by weighted probability of selection
        # for combination and reproduction
        @chromosomes = @chromosomes.sort_by(&:fitness)

        # Create New Generation {{{
        new_chromosomes = []

        while new_chromosomes.length < @chromosomes.length
          # choose two fit parents
          parent_one, parent_two = rand_parents

          old_bits1 = parent_one.encoded
          old_bits2 = parent_one.encoded

          #puts "Parent 1: #{parent_one}"
          #puts "Parent 2: #{parent_two}"

          # crossover
          unless @crossover_rate == 0
            new_child_one, new_child_two = crossover parent_one, parent_two
          else
            new_child_one = parent_one
            new_child_two = parent_two
          end

          # mutate
          new_child_one.mutate!
          new_child_two.mutate!

          # after crossover and mutation, if we actually have
          # a new  chromosome, we  reset the chromosome's age
          #puts "New Bits #{new_child_one.encoded}"
          #puts "Old Bits #{old_bits1}"

          if new_child_one.encoded != old_bits1
            new_child_one.age = 0
          end

          #puts "New Bits #{new_child_two.encoded}"
          #puts "Old Bits #{old_bits2}"

          if new_child_two.encoded != old_bits2
            new_child_two.age = 0
          end

          #puts "child #1 mask #{new_child_one.mask}"
          #puts "child #2 mask #{new_child_two.mask}"

          # add to population if valid
          new_chromosomes << new_child_one unless !new_child_one.valid?
          new_chromosomes << new_child_two unless !new_child_two.valid?
        end
        # }}}

        @old_fitness = @chromosomes.map(&:fitness).inject(:+)
        @new_fitness = new_chromosomes.map(&:fitness).inject(:+)

        # swap out all old members for the new ones
        @chromosomes = new_chromosomes

        #@chromosomes.each do |c|
        #  puts c
        #end
        #puts "evolved chromosomes"

        # reset  the roulette  wheel to  make sure  that the
        # next  iteration  of  evolution will  use  a  newly
        # recalculated  roulette  wheel  based on  this  new
        # generation
        @roulette_wheel = nil
      end

      def valid?(chromosome)
        return false unless chromosome.valid?
        matches = @chromosomes.reduce(0) do |acc,c|
          acc += chromosome.masked == c.masked ? 1 : 0
        end
        return true if matches == 0
        false
      end

    protected
      def split_string(string, split_point)
        [ string.slice(0..split_point), string.slice(split_point..string.length-1) ]
      end

      def crossover(p1, p2)
        die_roll = rand
        #puts "Crossover rate die roll: #{die_roll}"

        if die_roll <= @crossover_rate
          m1 = p1.mask
          m2 = p2.mask

          #puts "Performing crossover"
          bitlength = p1.encoded.length

          # choose a random split point
          split_point = rand(1..bitlength-2)

          # split each chromosome
          p1_l, p1_r = p1.split(split_point)
          p2_l, p2_r = p2.split(split_point)

          #puts "Mask One: #{m1.inspect}"
          #puts "Mask Two: #{m2.inspect}"

          m1_l, m1_r = split_string(m1, split_point)
          m2_l, m2_r = split_string(m2, split_point)

          new_mask_one = "#{m1_l}#{m2_r}"
          new_mask_two = "#{m2_l}#{m1_r}"

          #puts "New Mask One: #{new_mask_one}"
          #puts "New Mask Two: #{new_mask_two}"

          # swap the halves of each chromosome
          new_chromosome_one = "#{p1_l}#{p2_r}"
          new_chromosome_two = "#{p2_l}#{p1_r}"

          result_one = new_chromosome_one
          result_two = new_chromosome_two

          mask_one = new_mask_one
          mask_two = new_mask_two

          #puts "Splits P1: #{p1_l} #{p1_r}"
          #puts "New #1:    #{new_chromosome_one}"
          #puts ""

          #puts "Splits P2: #{p2_l} #{p2_r}"
          #puts "New #2:    #{new_chromosome_two}"
          #puts ""

          #puts ""
          #puts ""
          age_one = 0
          age_two = 0
        else
          #puts "randomly keeping some chromosomes"

          result_one = p1.encoded
          result_two = p2.encoded

          age_one = p1.age
          age_two = p2.age

          mask_one = p1.mask
          mask_two = p2.mask

          #puts "AgeOne: #{p1.age} BitsOne:#{result_one} MaskOne:#{mask_one}"
          #puts "AgeTwo: #{p2.age} BitsTwo:#{result_two} MaskTwo:#{mask_two}"

        end

        new_chromez_one = @chromosome_class.new(@chromosome_settings, result_one)
        new_chromez_two = @chromosome_class.new(@chromosome_settings, result_two)

        new_chromez_one.mask = mask_one
        new_chromez_two.mask = mask_two

        new_chromez_one.age = age_one
        new_chromez_two.age = age_two

        [new_chromez_one, new_chromez_two]
      end

      def rand_parents
        [rand_fit_member, rand_fit_member]
      end

      def rand_fit_member
        #puts "Pool#rand_fit_member"
        die_roll = rand
        #puts "Die Roll #{die_roll}"
        #puts "Roulette Wheel #{roulette_wheel}"
        new_chromosome_index = roulette_wheel.index { |c| c >= die_roll }
        #puts "New Chromosome IDX #{new_chromosome_index}"
        #puts "Chromosomes #{@chromosomes}"
        @chromosomes[new_chromosome_index]
      end

      def roulette_wheel
        #puts "Getting Roulette Wheel"
        if @roulette_wheel.nil?
          #puts "Building Roulette Wheel"
          # get total fitness score of the population
          total_fitness = @chromosomes.map(&:fitness).inject(:+)

          #puts "Total Fitness #{total_fitness}"

          if total_fitness == 0
            # if the  population has no fitness  yet then we
            # give  each  member  an  equal  probability  of
            # selection
            avg_probability = 1.to_f / @chromosomes.length.to_f
            #puts "Num Chromosomes #{@chromosomes.length}"
            #puts "Average Probability #{avg_probability}"
            @chromosomes.each do |c|
              c.probability = avg_probability
            end
          else
            # generate  weighted probabilities  so that  the
            # fittest results have a  larger chance of being
            # selected
            @chromosomes.each do |c|
              c.probability = c.fitness/total_fitness
            end
          end

          # create a roulette wheel where each item occupies an amount
          # of space from 0 to 100% relative to its probability
          #
          # e.g.
          #   turn an array of sorted probabilities like this:  [0.1,0.2,0.3,0.4]
          #   into a roulette wheel like this:                  [0.1,0.3,0.6,1.0]
          #
          # where we start at 0 and add each probability on to the next
          # i.e. we add each probability to the sum of the previous probabilities
          wheel = @chromosomes.map(&:probability).each
            .with_object({sum: 0})
            .map { |val,obj| obj[:sum] += val }

          #puts "Probabilities:     #{weighted_probabilities}"
          #puts "Roulette Wheel:    #{roulette_wheel.inspect}"
          #puts "Probabilities Sum: #{weighted_probabilities.inject(:+)}"
          #puts "Num Chromosomes:   #{population.length}"

          @roulette_wheel = wheel
        end

        @roulette_wheel
      end
    end
    # }}}
  end
  module NN
    class Network # {{{
      attr_reader :weight_layers, :layers, :output

      def initialize(config)
        @layers = []

        config.each do |c|
          layers << Layer.new(c[:neurons], c[:inputs])
        end
      end

      def layer_weights
        layers.map(&:weights)
      end

      def layer_inputs
        layers.map(&:inputs)
      end

      def weights
        layers.map(&:weights).flatten
      end

      def inputs
        layers.first.neurons.first.inputs
      end

      def weights=(values)
        # slice the array and feed each
        # slice to each layer
        layers.each_with_object({x:0}) do |l,o|
          w = values.slice(o[:x], l.total_num_inputs)
          l.weights = w
          o[:x] += l.total_num_inputs
        end
      end

      def inputs=(values)
        # feed the values in to the the bottom
        # layer of the neural network
        layers.first.inputs = values

        # propagate the data throughout the network
        layer_bound = layers.length - 1
        layers.each_with_index do |l,x|
          current_layer = layers[x]
          is_last_layer = x == layer_bound

          unless is_last_layer
            next_layer = layers[x + 1]

            # if there are more to go feed the output
            # of one layer in to another sequentially
            next_layer.inputs = current_layer.outputs
          end
        end
      end

      def outputs
        # retrieve the final output of the last layer
        layers.last.outputs
      end
    end
    # }}}

    class Layer # {{{
      attr_reader :neurons, :num_synapses

      def initialize(num_neurons, num_synapses, sigmoid=true)
        @num_synapses = num_synapses

        @neurons = (1..num_neurons).map do |x|
          Neuron.new num_synapses, sigmoid
        end
      end

      def total_num_inputs
        num_neurons * num_synapses
      end

      def p=(val)
        neurons.each do |n|
          n.p = val
        end
      end

      def num_neurons
        neurons.length
      end

      def outputs
        neurons.map(&:out)
      end

      def values
        neurons.map(&:value)
      end

      def inputs
        neurons.map(&:inputs).flatten
      end

      def weights
        neurons.map(&:weights).flatten
      end

      def weights=(w)
        # split and chunk the list evenly based
        # on the number of inputs per neuron
        weightsets = w.each_slice(num_synapses).to_a

        # feed each discrete set of weights to each
        # neuron in turn
        neurons.each_with_index do |n,x|
          n.weights = weightsets[x]
        end
      end

      def inputs=(i)
        # feed the set of inputs to each
        # neuron in turn
        neurons.each_with_index do |n,x|
          n.inputs = i
        end
      end
    end
    # }}}

    class Neuron # {{{
      attr_accessor :p, :activation
      attr_reader :e

      def initialize(num_synapses,sigmoid=true)
        @activation = 1
        @p = 1.0
        @e = Math::E

        @synapses = []

        if sigmoid
          output_sigmoid
        else
          output_binary
        end

        num_synapses.times do |x|
          synapses << Synapse.new
        end
      end

      def output_sigmoid
        @sigmoid = true
      end

      def output_binary
        @sigmoid = false
      end

      def sigmoid?
        @sigmoid ||= false
      end

      def a
        value
      end

      def sigmoid
        1 / (1 + (e ** ((a*-1)/p)))
      end

      def weights
        synapses.map(&:weight)
      end

      def weights=(weights=[])
        synapses.each_with_index do |s,x|
          synapses[x].weight = weights[x]
        end
      end

      def inputs
        synapses.map(&:signal)
      end

      def inputs=(inputs=[])
        synapses.each_with_index do |s,x|
          synapses[x].signal = inputs[x].to_f
        end
      end

      def synapses
        @synapses ||= []
      end

      def value
        synapses.map(&:out).reduce(:+)
      end

      def out
        if sigmoid?
          sigmoid
        else
          value > activation
        end
      end
    end
    # }}}

    class Synapse # {{{
      attr_reader :signal, :weight

      def initialize
        @signal = 0.0
        @weight = 1.0
      end

      def signal=(val)
        @signal = val.to_f
      end

      def weight=(val)
        @weight = val.to_f
      end

      def out(input=nil)
        input ||= signal
        input.to_f * weight.to_f
      end
    end
    # }}}
  end
  module LCS
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
        #puts "RAIN:GA attributes #{attributes}"

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

        #puts "Current cutpoint indexes #{cutpoint_indexes.inspect}"

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

        #puts "Known classes: #{@known_classes.inspect}"

        #puts "Sample length #{total_samples}"

        # get the probability of each class occuring
        # anywhere in the set
        @known_classes.each do |c|
          # get occurrences of this class within the total samples
          total_occur  = classes.count(c)
          #puts "Total occurrences of #{c}: #{total_occur}"

          unless total_occur == 0
            probability = total_occur.to_f / total_samples.to_f

            #puts "Probability of #{c}: #{probability}"

            # get num occurrences in left half
            all_probs << probability
          end
        end

        #puts "All class probabilities: #{all_probs}"

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

        #puts "Max entropy: #{max_entropy}"

        x = cutpoint_entropies.find_index(max_entropy)

        #puts "Cutpoint index: #{x}"

        options = datums[x]

        #puts "Cutpoint Data: #{options}"

        #gain = gain_of_cutpoint(options).abs
        gain = gain_of_cutpoint(options)
        mdlp = mdlp_of_cutpoint(options)

        #puts "Gain #{gain}"
        #puts "MDLP #{mdlp}"

        # if we should make the cut based on the MDLP formula
        if gain > mdlp
          #puts "Passes MDLP"

          # split at this cutpoint
          halves = split_array(features, x)

          #puts "Left split: #{halves[:left].length}"
          #puts "Right split: #{halves[:right].length}"

          #puts "Left split: #{halves[:left]}"
          #puts "Right split: #{halves[:right]}"

          s1 = halves[:left]
          s2 = halves[:right]

          # recurse on each side
          s1_cuts = make_cutpoints_mdlp(s1)
          #puts "RETURN FROM LEFT RECURSION #{s1_cuts.inspect}"
          s2_cuts = make_cutpoints_mdlp(s2)
          #puts "RETURN FROM RIGHT RECURSION #{s2_cuts.inspect}"
          #puts "RETURN INDEX: #{x}"

          # append to array
          cutpoint_indexes = [x, s1_cuts, s2_cuts.map{|c|c+x}].flatten
        end

        #puts "EOF index values: #{cutpoint_indexes}"
        cutpoint_indexes
      end

      def make_cutpoints_mdlp!(features)
        results = make_cutpoints_mdlp(features)
        #puts "Cutpoint results: #{results}"
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
end
