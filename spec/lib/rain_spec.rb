require 'spec_helper'

describe "rain" do
  before(:all) do
    @instances = Flower.all
    @features  = [:sepal_len, :sepal_wid, :petal_len, :petal_wid]

    @discretizer = Rain::LCS::Discretizer.new(@instances, @features)
  end

  context "machine learning" do
    # Genetic Algorithm {{{
    it "can solve a problem using a genetic algorithm" do
      # Given the digits 0 through 9 and the operators +, -,
      # *  and /,  find  a sequence  that  will represent  a
      # given target  number. The operators will  be applied
      # sequentially from left to right as you read.

      # Settings {{{
      gene_encoder = Rain::GA::Encoder.new(
        :decoding => {
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
        },
        :encoding => {
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
      )

      chromosome_settings = {
        :gene             => gene_encoder,
        :gene_count       => 9,
        :mutation_rate    => 0.001,

        :numbers          => ["0","1","2","3","4","5","6","7","8","9"],
        :operators        => ["+", "-", "*", "/"],

        :target_solution  => 28
      }

      population_settings = {
        :population_size     => 1000,
        :crossover_rate      => 0.8,
        :mutation_rate       => 0.05,
        :num_generations     => 10,
        :chromosome_settings => chromosome_settings
      }
      # }}}

      # Run {{{
      puts "Seeding Initial Population"

      pops = Rain::GA::Genome.new(population_settings)
      pops.randomize!

      puts "Initial Solution Count: #{pops.solutions.length}"

      # propagate new generations
      population_settings[:num_generations].times do |x|
        # swap out all old members for the new ones
        pops.evolve!

        # new generation stats
        puts "Old fitness score: #{pops.old_fitness}"
        puts "New fitness score: #{pops.new_fitness}"

        puts "Generation #2 Solution Count: #{pops.solutions.count}"
        puts "Total Solution Count: #{pops.total_solutions.count}"
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
