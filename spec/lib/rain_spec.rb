require 'spec_helper'

describe "Rain" do
  context "Genetic Algorithm" do # {{{
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
        :gene_sequence         => @formula_encoders,
        :population_size       => 100,
        :crossover_rate        => 0.7,
        :mutation_rate         => 0.001,
        :num_generations       => 10,
        :target_solution       => 28,
        :mask_percentage       => 0.0,
        :force_mask_percentage => false,
        :mask_entire_features  => false

      }
    end

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

      bs = "0000001001110001100100000110"
      c.bitstring = bs
      c.encoded.should == bs
      c.valid?.should be_true

      c.bitstring = "1111111111111111111111111111"
      c.valid?.should be_false
    end

    it "can generate a random mask" do
      c = Rain::GA::Chromosome.new(@chromosome_settings)

      bs = "0000001001110001100100000110"
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
      c.masked.should == (bs.to_i(2) | mask.to_i(2)).to_s(2).rjust(c.length, "0")
    end

    it "can mask a chromosome's bitstring" do
      c1 = Rain::GA::Chromosome.new(@chromosome_settings)
      c2 = Rain::GA::Chromosome.new(@chromosome_settings)

      bs1  = "0001001001110011000100000110"
      bs2  = "0010001001110001100101000100"
      mask = "0011000000000010100001000010"

      c1.bitstring = bs1
      c2.bitstring = bs2

      # the mask function should use an external mask if passed in
      c1.masked(mask).should == (bs1.to_i(2) | mask.to_i(2)).to_s(2).rjust(c1.length, "0")
      c2.masked(mask).should == (bs2.to_i(2) | mask.to_i(2)).to_s(2).rjust(c2.length, "0")

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

    it "should not allow duplicate chromosomes in the current population" do
      p = @pool_settings
      p[:mask_percentage] = 0.6

      pool = Rain::GA::Pool.new(@pool_settings)
      pool.randomize!
      match = pool.chromosomes.map do |c|
        match = pool.chromosomes.map do |c1|
          true if c.masked == c1.masked
          nil
        end.compact.any?
      end.any?
      match.should == false
    end

    it "can solve a problem using a genetic algorithm" do
      # Given the digits 0 through 9 and the operators +, -,
      # *  and /,  find  a sequence  that  will represent  a
      # given target  number. The operators will  be applied
      # sequentially from left to right as you read.

      # Run {{{
      puts "Seeding Initial Population"

      pool = FormulaPool.new(@pool_settings)

      pool.randomize!

      puts "Initial Solution Count: #{pool.solutions.length}"

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

  context "Neural Network" do # {{{
    context "Synapse" do
      it "should accept a weight" do
        s = Rain::NN::Synapse.new
        s.signal = 5
        s.signal.should == 5
      end
      it "should accept an input" do
        s = Rain::NN::Synapse.new
        s.weight = 5
        s.weight.should == 5
      end
      it "should give output provided input, based on weight" do
        s = Rain::NN::Synapse.new
        s.signal = 6.0
        s.weight = 0.5
        s.out.should == 3.0
        s.out(5).should == 2.5
      end
    end
    context "Neuron" do
      it "should initialize a number of synapses" do
        n = Rain::NN::Neuron.new(2, false)
        n.synapses.length.should == 2
      end
      it "should get outputs from inputs" do
        n = Rain::NN::Neuron.new(2)

        n.synapses[0].signal = 25
        n.synapses[0].weight = 0.2
        n.synapses[0].out.should == 5

        n.synapses[1].signal = 10
        n.synapses[1].weight = 0.3
        n.synapses[1].out.should == 3

        n.value.should == 8
      end
      it "should get accept an array of weights for each synapse" do
        n = Rain::NN::Neuron.new(2)

        n.weights = [ 0.2, 0.3 ]
        n.weights.should == [ 0.2, 0.3 ]
      end
      it "should get accept an array of inputs for each synapse" do
        n = Rain::NN::Neuron.new(2)

        n.inputs = [ 25, 10 ]
        n.inputs.should == [ 25, 10 ]
      end
      it "should have a sigmoid output" do
        n = Rain::NN::Neuron.new(2)
        n.sigmoid?.should be_true

        n.weights = [ 0.2, 0.3 ]
        n.inputs  = [ 25, 10 ]

        n.out.should == 0.9996646498695336

        n.p = 5

        n.out.should == 0.8320183851339245
      end
      it "should have a binary output if configured" do
        n = Rain::NN::Neuron.new(2, false)

        n.weights = [ 0.2, 0.3 ]
        n.inputs  = [ 25, 10 ]

        n.value.should == 8

        # default activation threshold is 1
        n.out.should be_true

        # if the activation threshold is lower
        # than the value, then the gate is open
        n.activation = 5
        n.out.should be_true

        # if the activation threshold is higher
        # than the value, then the gate is shut
        n.activation = 10
        n.out.should be_false
      end
    end
    context "Layer" do
      it "should have initialize a list of neurons" do
        l = Rain::NN::Layer.new(3,4)
        l.neurons.length.should == 3
        l.neurons.first.synapses.length.should == 4
        l.neurons.first.is_a?(Rain::NN::Neuron).should be_true
      end
      it "should accept a list of weights" do
        l = Rain::NN::Layer.new(2,2)
        l.weights = [0.2,0.3,0.9,0.7]
        l.weights.should == [0.2,0.3,0.9,0.7]
        l.neurons.first.weights.should == [0.2,0.3]
        l.neurons.last.weights.should  == [0.9,0.7]
      end
      it "should accept a list of inputs" do
        l = Rain::NN::Layer.new(2,4)
        l.inputs = [5.0,7.0,10.0,3.0]
        l.neurons.first.inputs.should == [5.0,7.0,10.0,3.0]
        l.neurons.last.inputs.should  == [5.0,7.0,10.0,3.0]
      end
      it "should return a list of outputs" do
        l = Rain::NN::Layer.new(2,2)

        l.weights = [0.2,0.3,0.9,0.7]
        l.inputs  = [5.0,7.0]

        l.values.should  == [3.1, 9.399999999999999]
        l.outputs.should == [0.9568927450589139, 0.9999172827771484]

        l.p = 5

        l.outputs.should == [0.6502185485738271, 0.8676111264579346]
      end
      it "outputs of one layer can be fed to the inputs of another" do
        bottom = Rain::NN::Layer.new(2,2)
        top = Rain::NN::Layer.new(1,2)

        bottom.weights = [0.2,0.3,0.9,0.7]
        bottom.inputs  = [5.0,7.0]

        top.inputs  = bottom.outputs
        top.weights = [0.8,0.4]

        top.outputs.should == [0.7623272339131819]

        bottom.p = 5
        top.p = 5

        top.inputs = bottom.outputs

        top.outputs.should == [0.5432525889838699]
      end
    end
    context "Network" do
      before :all do
        @config = [
          {neurons: 2, inputs: 2},
          {neurons: 1, inputs: 2}
        ]

        @config2 = [
          {neurons: 6, inputs: 10},
          {neurons: 2, inputs: 6}
        ]
      end

      it "should initialize layers" do
        n1 = Rain::NN::Network.new(@config)
        n1.layers.first.neurons.length.should == 2
        n1.layers.first.neurons.first.inputs.length.should == 2

        n1.layers.last.neurons.length.should == 1
        n1.layers.last.neurons.first.inputs.length.should == 2

        n2 = Rain::NN::Network.new(@config2)
        n2.layers.first.neurons.length.should == 6
        n2.layers.first.neurons.first.inputs.length.should == 10

        n2.layers.last.neurons.length.should == 2
        n2.layers.last.neurons.first.inputs.length.should == 6
      end
      it "should accept a list of weights" do
        n = Rain::NN::Network.new(@config)
        n.weights = [0.2,0.3,0.9,0.7,0.8,0.4]
        n.layer_weights.should == [[0.2,0.3,0.9,0.7],[0.8,0.4]]
      end
      it "should accept a list of inputs" do
        n = Rain::NN::Network.new(@config)
        n.inputs = [5.0,7.0]
        n.inputs.should == [5.0,7.0]
      end
      it "should produce output" do
        n = Rain::NN::Network.new(@config)
        n.weights = [0.2,0.3,0.9,0.7,0.8,0.4]
        n.inputs = [5.0,7.0]
        n.outputs.should == [0.7623272339131819]
      end
    end
  end
  # }}}

  context "Discretization" do # {{{
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
  # }}}
end
