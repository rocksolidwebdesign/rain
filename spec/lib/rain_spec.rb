require 'spec_helper'

describe "rain" do
  before(:all) do
    @instances = Flower.all
    @features  = [:sepal_len, :sepal_wid, :petal_len, :petal_wid]

    @discretizer = Rain::Discretizer.new(@instances, @features)
  end

  context "machine learning" do
    it "can solve a problem using a genetic algorithm" do
      # Given the digits 0 through 9 and the operators +, -,
      # *  and /,  find  a sequence  that  will represent  a
      # given target  number. The operators will  be applied
      # sequentially from left to right as you read.
      target_number = 28

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

      numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
      operators = ["+", "-", "*", "/"]

      num_chromosomes = 10
      chromosome_length = 9

      def valid(s)
        # number -> operator -> number -> operator -> number
        pattern = /^[0-9]([-+*\/][0-9])+$/
        div_zero = /\/0/

        # it matches, i.e. match is not nil
        !s.match(pattern).nil?

        # it doesn't try to divide by zero, i.e. matched divide by zero is nil
        s.match(div_zero).nil?
      end

      def random_chromosome(encoding, decoding, num_genes)
        genes = decoding.keys
        bitstring = ""
        num_genes.times do |x|
          random_gene_selector = rand(0...encoding.length)
          bitstring += genes[random_gene_selector]
        end
        bitstring
      end

      def random_formula_chromosome(encoding, decoding, num_genes, numbers, operators)
        gene_values = encoding.keys.map(&:to_s)
        #puts "Genes #{gene_values.inspect}"
        bitstring = ""
        #puts "Numbers: #{numbers}"
        first_number_selector = rand(0...numbers.length-1)
        #puts "First number selector: #{first_number_selector.inspect}"
        first_gene_selector = numbers[first_number_selector]
        #puts "First gene selector: #{first_gene_selector.inspect}"
        gene = encoding[first_gene_selector]
        #puts "First gene: #{gene.inspect}"
        bitstring += gene
        gene_type = 0
        (num_genes-1).times do |x|
          if x % 2 == 0
            operator_selector = rand(0...operators.length)
            #puts "Gene selector: #{operator_selector.inspect}"
            gene_selector = operators[operator_selector]
          else
            number_selector = rand(0...numbers.length)
            #puts "Gene selector: #{number_selector.inspect}"
            gene_selector = numbers[number_selector]
          end
          #puts "Gene selector: #{first_gene_selector.inspect}"
          gene = encoding[gene_selector]
          #puts "Gene: #{gene.inspect}"
          bitstring += gene
          gene_type += 1
        end
        bitstring
      end

      def decode_chromosome(chromosome, decoding)
        pattern = Regexp.union(decoding.keys)
        chromosome[:encoded].gsub(pattern, decoding)
      end

      population = []
      solutions = []

      population_size = 1000
      chromosome_count = 0

      crossover_rate = 0.7
      mutation_rate = 0.001

      while population.length < population_size
        chromosome = {}
        random_bitstring = random_formula_chromosome(gene_encoding, gene_decoding, chromosome_length, numbers, operators)
        chromosome = {:id => chromosome_count + 1, :fitness => 0, :encoded => random_bitstring}
        decoded = decode_chromosome(chromosome, gene_decoding)
        chromosome[:decoded] = decoded

        is_valid = valid(decoded)
        if is_valid
          formula = decoded.gsub(/([0-9])/, '\1.to_f')
          result = eval(formula)
          is_solution = target_number == result ? true : false
          chromosome[:result] = result

          # put some reasonable bounds on it
          max_fitness = 1.999
          max_distance = 15
          distance = (target_number - result).abs
          if distance > max_distance
            distance = max_distance
          end

          unless distance == 0
            fitness = 1.to_f/distance.to_f
            if fitness > max_fitness
              fitness = max_fitness
            end
          else
            fitness = 2
          end

          chromosome[:fitness] = fitness

          if is_solution
            solutions << chromosome
          else
            population << chromosome
          end

          #c = chromosome
          #puts "#{c[:encoded]}\t#{c[:decoded]}\t#{c[:result].to_s.ljust(20, '0')}\t#{c[:is_solution].to_s}\tFitness: #{c[:fitness]}\tRoulette: #{c[:roulette]}"
          chromosome_count += 1
        end
      end

      # build roulette wheel
      total_fitness = population.map{|c|c[:fitness]}.inject(:+)
      population.each do |c|
        c[:roulette] = c[:fitness]/total_fitness
      end

      population = population.sort_by{|c|c[:roulette]}
      #population.each do |c|
      #  puts "#{c[:id]}\t#{c[:encoded]}\t#{c[:decoded]}\t#{c[:result].to_s.ljust(17, '0')}\t#{c[:is_solution] ? 'TRUE' : 'false'}\tFitness: #{c[:fitness].to_s.ljust(17, '0')}\tRoulette: #{c[:roulette]}"
      #end

      weighted_probabilities = population.map{|c|c[:roulette]}

      total = 0;
      roulette_wheel = weighted_probabilities.map { |v| total += v }

      sum = lambda { |sum,val| sum += val }
      #puts "Probabilities: #{weighted_probabilities}"
      #puts "Roulette Wheel: #{roulette_wheel.inspect}"
      puts "Probabilities Sum: #{weighted_probabilities.inject(0){|sum,val|sum+=val}}"
      puts "Num Chromosomes: #{population.length}"

      # build a new population from the old one
      new_population = []
      while new_population.length < population.length
        # select a random chromosome with, ideally, on average
        # a higher fitness score
        random_percentage    =  rand(0.0000000000000000..1.0000000000000000)
        roulette_wheel_roll  =  roulette_wheel.select { |c| c >= random_percentage }.first
        new_chromosome_index =  roulette_wheel.index(roulette_wheel_roll)

        new_population << population[new_chromosome_index]
      end

      get_fitness = lambda { |c| c[:fitness] }
      sum_of_old_chromosome_fitnesses = population.map(&get_fitness).inject(0){|sum,val|sum+=val}
      sum_of_new_chromosome_fitnesses = new_population.map(&get_fitness).inject(0){|sum,val|sum+=val}

      puts "Old fitness score: #{sum_of_old_chromosome_fitnesses}"
      puts "New fitness score: #{sum_of_new_chromosome_fitnesses}"
    end
  end

  context "discretizer" do
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

    #it "can create bayesian cut points" do
    #  1.should == 1
    #end

    #it "can create 1-rule cut points" do
    #  1.should == 1
    #end

    it "can create entropy cut points" do
      # put an equal number of instances in each bin
      correct_cutpoints = {
        sepal_len: [5.4,6.1],
        sepal_wid: [4.4],
        petal_len: [1.9,4.9,6.9],
        petal_wid: [0.6,1.6,2.5]
      }

      # this is basically an arbirary number of bins
      feature_sets = {
        :sepal_len => Flower.select('sepal_len AS value, classification').order(:sepal_len),
        :sepal_wid => Flower.select('sepal_wid AS value, classification').order(:sepal_wid),
        :petal_len => Flower.select('petal_len AS value, classification').order(:petal_len),
        :petal_wid => Flower.select('petal_wid AS value, classification').order(:petal_wid)
      }

      results = @discretizer.make_cutpoints_mdlp(feature_sets[:sepal_len])

      puts "Cutpoint index results: #{results}"
      results.should == correct_cutpoints[:sepal_len]
    end
  end
end
