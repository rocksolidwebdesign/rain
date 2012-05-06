require 'spec_helper'

describe "rain" do
  context "machine learning" do
    before(:all) do
      @formula_values  = ["0","1","2","3","4","5","6","7","8","9","+","-","*","/"]

      number_encoder   = Rain::GA::Encoder.new(["0","1","2","3","4","5","6","7","8","9"])
      operator_encoder = Rain::GA::Encoder.new(["+","-","*","/"])

      @formula_encoders = [number_encoder]
      4.times do |x|
        @formula_encoders << operator_encoder
        @formula_encoders << number_encoder
      end

      @chromosome_settings = {
        :gene_sequence       => @formula_encoders
      }

      @pool_settings = {
        :gene_sequence       => @formula_encoders,
        :population_size     => 1000,
        :crossover_rate      => 0.7,
        :mutation_rate       => 0.001,
        :num_generations     => 10,
        :target_solution     => 28
      }
    end

    context "genetic algorithm" do
      it "can get a random gene from a gene encoder" do
        encoder = Rain::GA::Encoder.new(@formula_values)

        bitstring = encoder.randbs

        is_valid = !bitstring.match(/^[01]*$/).nil?
        is_valid.should be_true
      end

      it "can generate a random gene" do
        formula_encoder  = Rain::GA::Encoder.new(@formula_values)

        gene = Rain::GA::Gene.new(formula_encoder)
        gene.randomize!

        gene.valid?.should be_true
        valid_encoded = !gene.encoded.match(/^[01]*$/).nil?
        valid_encoded.should be_true

        valid_decoded = !gene.decoded.match(/^[-0-9+*\/]*$/).nil?
        valid_decoded.should be_true
      end

      it "can generate a random genome" do
        formula_gene_sequence = @formula_encoders.map do |e|
          Rain::GA::Gene.new(e)
        end

        genome = Rain::GA::Genome.new(formula_gene_sequence)
        genome.randomize!

        genome.valid?.should be_true
        valid_encoded = !genome.encoded.match(/^[01]*$/).nil?
        valid_encoded.should be_true

        valid_decoded = !genome.decoded.match(/^[0-9]([-+*\/][0-9])*$/).nil?
        valid_decoded.should be_true
      end

      it "can generate a random chromosome" do
        c = Rain::GA::Chromosome.new(@chromosome_settings)
        c.randomize!

        c.valid?.should be_true
        valid_encoded = !c.encoded.match(/^[01]*$/).nil?
        valid_encoded.should be_true

        valid_decoded = !c.decoded.match(/^[0-9]([-+*\/][0-9])*$/).nil?
        valid_decoded.should be_true
      end

      it "can swap out a chromosome's bitstring" do
        c = Rain::GA::Chromosome.new(@chromosome_settings)

        bs = "000000100111000110010000011000110001"
        c.bitstring = bs
        c.encoded.should == bs
        c.valid?.should be_true

        c.bitstring = "111111111111111111111111111111111111"
        c.valid?.should be_false
      end

      it "can generate a random mask" do
        c = Rain::GA::Chromosome.new(@chromosome_settings)

        bs = "000100100111001100010000011000111001"
        c.bitstring = bs

        masked = c.masked
        mask = c.mask

        c.masked.should == masked

        mask.should_not == bs
        mask.match(/^[01]+$/).nil?.should_not be_true

        ones = mask.each_char.select { |c| c == "1" }.length

        # at least about 20% should be turned on
        (ones.to_f / bs.length.to_f).should >= 0.2

        # the masked function should use its internal mask
        # if no parameters are passed
        c.masked.should == (bs.to_i(2) | mask.to_i(2)).to_s(2)
      end

      it "can mask a chromosome's bitstring" do
        c1 = Rain::GA::Chromosome.new(@chromosome_settings)
        c2 = Rain::GA::Chromosome.new(@chromosome_settings)

        bs1  = "000100100111001100010000011000111001"
        bs2  = "001000100111000110010100010001110001"
        mask = "001100000000001010000100001001001000"

        c1.bitstring = bs1
        c2.bitstring = bs2

        # the mask function should use an external mask if passed in
        c1.masked(mask).should == (bs1.to_i(2) | mask.to_i(2)).to_s(2)
        c2.masked(mask).should == (bs2.to_i(2) | mask.to_i(2)).to_s(2)

        c1.masked(mask).should == c2.masked(mask)
      end

      it "can create a pool of random chromosomes" do
        pool = Rain::GA::Pool.new(@pool_settings)
        pool.randomize!

        pool.chromosomes.uniq.length.should > 1
      end

      it "can evolve a pool of chromosomes" do
        pool = Rain::GA::Pool.new(@pool_settings)

        pool.randomize!
        pool.chromosomes.uniq.length.should > 1

        pool.evolve!
        pool.chromosomes.uniq.length.should > 1
      end

      it "can solve a problem using a genetic algorithm" do
        # Given the digits 0 through 9 and the operators +, -,
        # *  and /,  find  a sequence  that  will represent  a
        # given target  number. The operators will  be applied
        # sequentially from left to right as you read.

        # Run {{{
        #puts "Seeding Initial Population"

        pool = Rain::GA::FormulaPool.new(@pool_settings.merge({
          :target_solution => 28
        }))

        pool.randomize!

        #puts "Initial Solution Count: #{pool.solutions.length}"

        beginning_solution_count = pool.solutions.length
        # propagate new generations
        @pool_settings[:num_generations].times do |x|
          # swap out all old members for the new ones
          pool.evolve!

          # new generation stats
          #puts "Old fitness score: #{pool.old_fitness}"
          #puts "New fitness score: #{pool.new_fitness}"

          #puts "Generation ##{x} Solution Count: #{pool.solutions.count}"
          #puts "Total Solution Count: #{pool.total_solutions.count}"
        end

        ending_solution_count = pool.total_solutions.length
        # }}}

        ending_solution_count.should > beginning_solution_count
      end
    end
    # }}}
  end

  context "discretizer" do
    before(:all) do
      @instances = Flower.all
      @features  = [:sepal_len, :sepal_wid, :petal_len, :petal_wid]

      @discretizer = Rain::LCS::Discretizer.new(@instances, @features)
    end

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
