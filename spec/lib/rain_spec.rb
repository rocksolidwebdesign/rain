require 'spec_helper'

describe "rain" do
  before(:all) do
    @instances = Flower.all
    @features  = [:sepal_len, :sepal_wid, :petal_len, :petal_wid]

    @discretizer = Rain::Discretizer.new(@instances, @features)
  end

  context "machine learning" do
    # Genetic Algorithm {{{
    it "can solve a problem using a genetic algorithm" do
      # Given the digits 0 through 9 and the operators +, -,
      # *  and /,  find  a sequence  that  will represent  a
      # given target  number. The operators will  be applied
      # sequentially from left to right as you read.

      # Methods {{{
      # Utility Methods {{{
      def split_array(values, x)
        [ values.slice(0,x), values.slice(x..values.length-1) ]
      end
      # }}}

      # Chromosome Methods {{{
      def dump_chromosome(c)
        #"#{c[:id]}\t#{c[:encoded]}\t#{c[:decoded]}\t#{c[:result].to_s.ljust(17, '0')}\t#{c[:is_solution] ? 'TRUE' : 'false'}\tFitness: #{c[:fitness].to_s.ljust(17, '0')}\t%: #{c[:probability]}"
        "#{c[:encoded]}\t#{c[:decoded]}\t#{c[:result].to_s.ljust(17, '0')}\t#{c[:is_solution] ? 'TRUE' : 'false'}\tFitness: #{c[:fitness].to_s.ljust(17, '0')}\t%: #{c[:probability]}"
      end

      def generate_random_bitstring(encoding, decoding, num_genes)
        genes = decoding.keys
        bitstring = ""
        num_genes.times do |x|
          random_gene_selector = rand(0...encoding.length)
          bitstring += genes[random_gene_selector]
        end
        bitstring
      end

      def generate_random_bitstring_for_formula(encoding, decoding, num_genes, numbers, operators)
        gene_values = encoding.keys.map(&:to_s)
        bitstring = ""
        first_number_selector = rand(0...numbers.length-1)
        first_gene_selector = numbers[first_number_selector]
        gene = encoding[first_gene_selector]
        bitstring += gene
        gene_type = 0
        (num_genes-1).times do |x|
          if x % 2 == 0
            operator_selector = rand(0...operators.length)
            gene_selector = operators[operator_selector]
          else
            number_selector = rand(0...numbers.length)
            gene_selector = numbers[number_selector]
          end
          gene = encoding[gene_selector]
          bitstring += gene
          gene_type += 1
        end
        bitstring
      end

      def build_chromosome_for_formula(bitstring, gene_decoding, target_solution)
        chromosome = nil

        # decode the gene sequence
        decoded_bitstring = decode_bitstring_for_formula(
          bitstring, gene_decoding
        )

        # Process Chromosome {{{
        if valid_gene_sequence_for_formula(decoded_bitstring)

          # initialize a chromosome object with an
          # ID and the random gene sequence
          chromosome =  {
            :encoded => bitstring,
            :decoded => decoded_bitstring,
            :result  => calculate_result_for_formula(decoded_bitstring),
            :fitness => calculate_fitness_for_formula(decoded_bitstring, target_solution)
          }
          # }}}
        end

        chromosome
      end

      def valid_gene_sequence_for_formula(formula)
        s = formula

        # number -> operator -> number -> operator -> number
        pattern = /^[0-9]([-+*\/][0-9])+$/
        div_zero = /\/0/

        # it matches, i.e. match is not nil
        valid_pattern = !s.match(pattern).nil?

        # it doesn't try to divide by zero, i.e. matched divide by zero is nil
        no_div_by_zero = s.match(div_zero).nil?

        #puts "Formula: #{formula}, Valid Pattern: #{valid_pattern}, No Div 0: #{no_div_by_zero}"

        if valid_pattern && no_div_by_zero
          return true
        end

        false
      end

      def decode_bitstring_for_formula(bitstring, decoding)
        pattern = Regexp.union(decoding.keys)
        bitstring.gsub(pattern, decoding)
      end

      def calculate_result_for_formula(formula)
        formula = formula.gsub(/([0-9])/, ' \1.to_f ')
        #puts "Calculated Formula: #{formula.inspect}"
        result = eval(formula)
      end

      def calculate_fitness_for_formula(formula, target_solution)
        result = calculate_result_for_formula(formula)

        # Calculate Fitness {{{
        # put some reasonable bounds on it
        max_fitness  = 1.999
        max_distance = 15

        # filter/bound unfit results where the distance
        # from the solution is too large
        distance = (target_solution - result).abs
        if distance > max_distance
          distance = max_distance
        end

        # a distance of zero from the solution
        # means that this is a solution
        if distance == 0
          # prevent dividing by zero
          fitness = 2
        else
          fitness = 1.to_f/distance.to_f

          # filter/bound the fitness to prevent
          # overfitting the results
          if fitness > max_fitness
            fitness = max_fitness
          end
        end
        # }}}

        fitness
      end

      def is_solution_to_formula(formula, target_solution)
        target_solution == calculate_result_for_formula(formula)
      end
      # }}}

      # Population Methods {{{
      def generate_random_population
      end

      def get_roulette_wheel(population)
        # get total fitness score of the population
        total_fitness = population.map{|c|c[:fitness]}.inject(:+)

        # generate weighted probabilities so that
        # the fittest results have a larger chance
        # of being selected
        population.each do |c|
          c[:probability] = c[:fitness]/total_fitness
        end

        weighted_probabilities = population.map{|c|c[:probability]}

        # create a roulette wheel where each item occupies an amount
        # of space from 0 to 100% relative to its probability
        #
        # e.g.
        #   turn an array of sorted probabilities like this:  [0.1,0.2,0.3,0.4]
        #   into a roulette wheel like this:                  [0.1,0.3,0.6,1.0]
        #
        # where we start at 0 and add each probability on to the next
        # i.e. we add each probability to the sum of the previous probabilities
        roulette_wheel = weighted_probabilities.each.with_object({sum: 0}).map { |val,obj| obj[:sum] += val }

        # a more readable version of the above
        # roulette wheel generation code
        #total = 0;
        #roulette_wheel = weighted_probabilities.map { |v| total += v }

        #puts "Probabilities:     #{weighted_probabilities}"
        #puts "Roulette Wheel:    #{roulette_wheel.inspect}"
        #puts "Probabilities Sum: #{weighted_probabilities.inject(:+)}"
        #puts "Num Chromosomes:   #{population.length}"

        roulette_wheel
      end

      def crossover(p1_bitstring, p2_bitstring, crossover_rate)
        die_roll = rand
        #puts "Crossover rate die roll: #{die_roll}"
        if die_roll <= crossover_rate
          #puts "Performing crossover"
          bitlength = p1_bitstring.length

          # choose a random split point
          split_point = rand(1..bitlength-2)

          # split each chromosome
          p1_l, p1_r = split_array(p1_bitstring, split_point)
          p2_l, p2_r = split_array(p2_bitstring, split_point)

          new_chromosome_one = "#{p1_l} #{p2_r}"
          new_chromosome_two = "#{p2_l} #{p1_r}"

          #puts "Splits P1: #{p1_l} #{p1_r}"
          #puts "New #1:    #{new_chromosome_one}"
          #puts ""

          #puts "Splits P2: #{p2_l} #{p2_r}"
          #puts "New #2:    #{new_chromosome_two}"
          #puts ""

          #puts ""
          #puts ""

          result_one = new_chromosome_one
          result_two = new_chromosome_two

          # swap the last portions
        else
          result_one = p1_bitstring
          result_two = p2_bitstring
        end

        [result_one, result_two]
      end

      def mutate(old_bitstring, mutation_rate)
        mutated_bitstring = ""

        num_mutations = 0
        bit_counter = 0
        mutated_indexes = []
        old_bitstring.each_char do |c|
          new_bit = c

          # optionally perform mutation
          die_roll = rand
          if die_roll <= mutation_rate
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

        mutated_bitstring
      end

      def select_random_fittest_member(roulette_wheel, population)
        random_percentage    =  rand
        new_chromosome_index =  roulette_wheel.index { |c| c >= random_percentage }
        result =  population[new_chromosome_index]

        result
      end
      # }}}
      # }}}

      # Vars {{{
      # Encoding {{{
      gene_decoding = {
        "0000" => "0",
        "0001" => "1",
        "0010" => "2",
        "0011" => "3",
        "0100" => "4",
        "0101" => "5",
        "0110" => "6",
        "0111" => "7",
        "1000" => "8",
        "1001" => "9",
        "1010" => "+",
        "1011" => "-",
        "1100" => "*",
        "1101" => "/"
      }

      gene_encoding = {
        "0" => "0000",
        "1" => "0001",
        "2" => "0010",
        "3" => "0011",
        "4" => "0100",
        "5" => "0101",
        "6" => "0110",
        "7" => "0111",
        "8" => "1000",
        "9" => "1001",
        "+" => "1010",
        "-" => "1011",
        "*" => "1100",
        "/" => "1101"
      }
      # }}}

      target_solution = 28

      # binned gene/feature values
      numbers   = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
      operators = ["+", "-", "*", "/"]

      # variables for process control
      num_generations         =  10
      population_size         =  1000
      chromosome_gene_count   =  9
      crossover_rate          =  0.7
      mutation_rate           =  0.001

      # initialize containers
      population = []
      solutions = []
      # }}}

      # Seed Population {{{
      puts "Seeding Initial Population"

      while population.length < population_size
        # generate a random gene sequence
        bitstring = generate_random_bitstring_for_formula(
          gene_encoding, gene_decoding,
          chromosome_gene_count,
          numbers, operators
        )

        # chromosome builder returns nil if chromosome is invalid
        new_chromosome = build_chromosome_for_formula(bitstring, gene_decoding, target_solution)

        unless new_chromosome.nil?
          # if this chromosome solves the problem
          if is_solution_to_formula(new_chromosome[:decoded], target_solution)
            # then add it to the list of solutions
            solutions << new_chromosome
          end

          # add it  to the population regardless  of whether
          # it is  a solution  or not  to allow  mutation of
          # further generations based on actual solutions as
          # well as simply "very fit" results
          population << new_chromosome
        end
      end

      puts "Initial Solution Count: #{solutions.length}"
      # }}}

      # Propagate New Generations {{{
      num_generations.times do |x|
        # pre-sort the population by fitness
        # i.e. by weighted probability of selection
        # for combination and reproduction
        population = population.sort_by{|c|c[:fitness]}

        # Create New Generation {{{
        new_population = []
        roulette_wheel = get_roulette_wheel(population)

        while new_population.length < population.length
          # choose two fit parents
          parent_one = select_random_fittest_member(roulette_wheel, population)
          parent_two = select_random_fittest_member(roulette_wheel, population)

          # perform crossover
          new_child_one, new_child_two = crossover(parent_one[:encoded], parent_two[:encoded], crossover_rate)

          # mutate
          new_child_one = mutate(new_child_one, mutation_rate)
          new_child_two = mutate(new_child_two, mutation_rate)

          # build chromosome objects for the new gene sequences
          new_chromosome_one = build_chromosome_for_formula(new_child_one, gene_decoding, target_solution)
          new_chromosome_two = build_chromosome_for_formula(new_child_two, gene_decoding, target_solution)

          new_population << new_chromosome_one unless new_chromosome_one.nil?
          new_population << new_chromosome_two unless new_chromosome_two.nil?
        end
        # }}}

        # New Generation Stats {{{
        get_fitness = lambda { |c| c[:fitness] }
        old_population_fitness = population.map(&get_fitness).inject(:+)
        new_population_fitness = new_population.map(&get_fitness).inject(:+)

        puts "Old fitness score: #{old_population_fitness}"
        puts "New fitness score: #{new_population_fitness}"

        this_gen_solutions = []
        new_population.each do |c|
          if is_solution_to_formula(c[:decoded], target_solution)
            # then add it to the list of solutions
            this_gen_solutions << new_chromosome
          end
        end

        solutions += this_gen_solutions

        puts "Generation #2 Solution Count: #{this_gen_solutions.length}"
        puts "Total Solution Count: #{solutions.length}"
        # }}}

        # swap out all old members for the new ones
        population = new_population
      end
      # }}}
    end
    # }}}
  end

  context "discretizer" do
    # Equal Width {{{
    it "can create equal-width cut points" do
      correct_cutpoints = {
        sepal_len: [5.2,6.1,7.0],
        sepal_wid: [2.6,3.2,3.8],
        petal_len: [1.9,3.9,5.4],
        petal_wid: [0.6,1.3,1.9]
      }

      # this is basically an arbirary number of bins
      num_bins = 4

      # we need to fit the cut points to the actual
      # data in order to pass the test using the
      # bin values from Iris
      @discretizer.make_cutpoints_equalwidth_fit!(num_bins)
      @discretizer.feature_cut_points.should == correct_cutpoints
    end
    # }}}

    # Equal Length {{{
    it "can create equal-length cut points" do
      # put an equal number of instances in each bin
      correct_cutpoints = {
        sepal_len: [5.1,5.8,6.4],
        sepal_wid: [2.8,3.0,3.3],
        petal_len: [1.6,4.4,5.1],
        petal_wid: [0.3,1.3,1.8]
      }

      # this is basically an arbirary number of bins
      num_bins = 4

      @discretizer.make_cutpoints_equallength!(num_bins)
      @discretizer.feature_cut_points.should == correct_cutpoints
    end
    # }}}

    # Entropy MDLP {{{
    #it "can create entropy mdlp cut points" do
    #  # this isn't correct yet, uncomment while working on it

    #  # put an equal number of instances in each bin
    #  correct_cutpoints = {
    #    sepal_len: [5.4,6.1],
    #    sepal_wid: [4.4],
    #    petal_len: [1.9,4.9,6.9],
    #    petal_wid: [0.6,1.6,2.5]
    #  }

    #  # this is basically an arbirary number of bins
    #  feature_sets = {
    #    :sepal_len => Flower.select('sepal_len AS value, classification').order(:sepal_len),
    #    :sepal_wid => Flower.select('sepal_wid AS value, classification').order(:sepal_wid),
    #    :petal_len => Flower.select('petal_len AS value, classification').order(:petal_len),
    #    :petal_wid => Flower.select('petal_wid AS value, classification').order(:petal_wid)
    #  }

    #  results = @discretizer.make_cutpoints_mdlp(feature_sets[:sepal_len])

    #  #puts "Cutpoint index results: #{results}"

    #  results.should == correct_cutpoints[:sepal_len]
    #end
    # }}}
  end
end
